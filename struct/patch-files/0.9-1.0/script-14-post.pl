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
convert_stories();
auto_increment();
logout_box();
diarysub_box();
show_ad_box();
ad_box();
related_links();
move_vars();
confirm_users();
cc_bill_orders();
perms();
section_title();
subpay_type_select();
digest_keys();
box_form();
one_var();

sub one_var {
	mesg("\nUpdating site controls formn\n");

	mesg("  Grabbing block edit_one_var...");
	$query = "SELECT block FROM blocks WHERE bid = 'edit_one_var'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($var) = $sth->fetchrow_array();
	$sth->finish;
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($var =~ /%%%%description%%%%/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Enlarging form size and adding description...");
	$var =~ s/rows="2"\s+name="value"/rows="12" name="value"/;
	$var =~ s/(%%value%%<\/textarea>\r?\n?\s*<\/td>\r?\n?\s*<\/tr>)/$1\n\t<tr>\n\t\t<td colspan="2">%%norm_font%%%%description%%%%norm_font_end%%<\/td>\n\t<\/tr>/;
	mesg("done\n");

	mesg("  Putting block back in...");
	$query = "UPDATE blocks SET block = " . $dbh->quote($var) . " WHERE bid = 'edit_one_var'";
	$dbh->do($query);
	mesg("done\n");
}

sub box_form {
	mesg("\nUpdating boxes admin form\n");

	mesg("  Grabbing block admin_boxes_form...");
	$query = "SELECT block FROM blocks WHERE bid = 'admin_boxes_form'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($box_form) = $sth->fetchrow_array();
	$sth->finish;
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box_form =~ /admin_boxes_template_link/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Patching admin_boxes_form...");
	$box_form =~ s/(%%admin_boxes_template_menu%%)/$1 %%admin_boxes_template_link%%/;
	mesg("done\n");

	mesg("  Putting block back in...");
	my $query = "UPDATE blocks SET block = " . $dbh->quote($box_form) . " WHERE bid = 'admin_boxes_form'";
	$dbh->do($query);
	mesg("done\n");
}

sub digest_keys {
	mesg("\nConverting digest key format\n");

	mesg("  Grabbing digest_storyformat...");
	$query = "SELECT block FROM blocks WHERE bid = 'digest_storyformat'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($format) = $sth->fetchrow_array();
	$sth->finish;
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($format =~ /__\w+__/) {
		mesg("not found. Continuing\n");
	} else {
		mesg("found. Skipping.\n");
		return;
	}

	mesg("  Converting story format...");
	$format =~ s/__([a-z]+)__/%%$1%%/g;
	$format =~ s/\\n/\n/g;
	mesg("done\n");

	mesg("  Putting digest_storyformat back in...");
	$query = "UPDATE blocks SET block = " . $dbh->quote($format) . " WHERE bid = 'digest_storyformat'";
	$dbh->do($query);
	mesg("done\n");

	mesg("  Processing digest header/footer blocks\n");
	$query = "SELECT bid,block FROM blocks WHERE bid = 'digest_header' OR bid = 'digest_footer' OR bid = 'digest_headerfooter'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	while (my ($bid, $value) = $sth->fetchrow_array) {
		mesg("    $bid\n      Converting...");
		$value =~ s/__([A-Z]+)__/%%$1%%/g;
		$value =~ s/\\n/\n/g;
		mesg("done\n      Putting back in...");
		$query = "UPDATE blocks SET block = " . $dbh->quote($value) . " WHERE bid = '$bid'";
		$dbh->do($query);
		mesg("done\n");
	}
}

sub subpay_type_select {
	mesg("\nTurning off debugging in subpay_type_select box\n");

	mesg("  Grabbing subpay_type_select box...");
	my $box = grab_box($dbh, 'subpay_type_select');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /\#warn \"Months/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Turning off debugging...");
	$box =~ s/(warn \"Month)/\#$1/;
	mesg("done\n");

	mesg("  Putting box back in...");
	update_box($dbh, 'subpay_type_select', $box);
	mesg("done\n");
}

sub section_title {
	mesg("\nFixing section_title_subsections box\n");

	mesg("  Grabbing section_title_subsections box...");
	my $box = grab_box($dbh, 'section_title_subsections');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /have_section_perm\(.norm_read_stories/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Patching box...");
	$box =~ s/(\$op\s*eq\s*\'section\'\s*\)\s*\{\r?\n?)/$1  return unless \$S->have_section_perm\(\'norm_read_stories\', \$section\);\n/;
	mesg("done\n");

	mesg("  Putting box back in...");
	update_box($dbh, 'section_title_subsections', $box);
	mesg("done\n");
}

sub perms {
	mesg("\nRemoving extra perms\n");

	mesg("  Grabbing perms var...");
	$query = "SELECT value FROM vars WHERE name = 'perms'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($perms) = $sth->fetchrow_array();
	$sth->finish;
	mesg("done\n");

	mesg("  Removing edit_perms and show_perms...");
	$perms =~ s/edit_perms,?\r?\n?//;
	$perms =~ s/show_perms,?\r?\n?//;
	mesg("done\n");

	mesg("  Putting var back in...");
	$query = "UPDATE vars SET value = " . $dbh->quote($perms) . " WHERE name = 'perms'";
	$dbh->do($query);
	mesg("done\n");
}

sub cc_bill_orders {
	mesg("\nTrimming cc_bill_orders box\n");

	mesg("  Grabbing cc_bill_orders box...");
	my $box = grab_box($dbh, 'cc_bill_orders');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /perpetual\s*!=\s*1/) {
		mesg("not found. Continuing.\n");
	} else {
		mesg("found. Skipping.\n");
		return;
	}

	mesg("  Removing code for marking ads inactive...");
	$box =~ s/# Set finished.+database\r?\n?//;
	$box =~ s/\(\$rv, \$sth\) = \$S->db_update.+?perpetual\s*!=\s*1.+?\$sth->finish\(\);\r?\n?//s;
	mesg("done\n");

	mesg("  Putting box back in...");
	update_box($dbh, 'cc_bill_orders', $box);
	mesg("done\n");
}

sub confirm_users {
	mesg("\nConfirming unconfirmed users\n");

	mesg("  Updating users table...");
	$query = "UPDATE users SET passwd = bio, bio = '', is_new_account = 1 WHERE passwd REGEXP '^[0-9]+\$'";
	$dbh->do($query);
	mesg("done\n");
}

sub convert_stories {
	mesg("\nConverting stories' table to numeric aid\n");

	mesg("  Checking for previous patch run...");
	$query = "SELECT aid FROM stories WHERE aid REGEXP '[^-0-9]' LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($aid_test) = $sth->fetchrow_array;
	$sth->finish;
	if (defined $aid_test) {
		mesg("not found. Continuing.\n");
	} else {
		mesg("found. Skipping.\n");
		return;
	}

	mesg("  Adding temporary column...");
	$query = "ALTER TABLE stories ADD COLUMN temp_aid INT(11) NOT NULL AFTER aid";
	$rv = $dbh->do($query);
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Gathering data...");
	$query = "SELECT stories.aid, users.uid FROM stories, users WHERE stories.aid = users.nickname GROUP BY stories.aid";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute;
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Inserting numeric aid's");
	my $update_sth = $dbh->prepare("UPDATE stories SET temp_aid = ? WHERE aid = ?");
	while (my ($nick, $uid) = $sth->fetchrow_array) {
		mesg('.');
		$update_sth->execute($uid, $nick);
	}
	mesg("done\n");
	$update_sth->finish;
	$sth->finish;

	mesg("  Removing old aid column...");
	$query = "ALTER TABLE stories DROP COLUMN aid";
	$rv = $dbh->do($query);
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Renaming temporary column to aid column...");
	$query = "ALTER TABLE stories CHANGE temp_aid aid INT(11) NOT NULL";
	$dbh->do($query);
	mesg("done\n");
}

sub move_vars {
	mesg("\nMoving slogan, digest_subject, poll_img, and fonts from vars to blocks\n");

	mesg("  Grabbing var data...");
	$query = q|SELECT name, value, description FROM vars WHERE category LIKE '%Fonts%' OR name = 'slogan' OR name = 'digest_subject' OR name = 'poll_img'|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute;
	unless ($rv > 0) {
		mesg("none found. Skipping.\n");
		$sth->finish;
		return;
	}
	mesg("done\n  Inserting/Updating Blocks (from Vars)...\n");
        my $upd_sth = $dbh->prepare("UPDATE blocks SET block = ?, description = ?, category = ? WHERE bid = ?");
	my $ins_sth = $dbh->prepare("INSERT INTO blocks (bid, block, description, category) VALUES (?, ?, ?, ?)");
	my $remove;
	while (my ($name, $val, $desc) = $sth->fetchrow_array) {
		my $category = ($name eq 'slogan') ? 'site_html' :
			(($name eq 'digest_subject') ? 'email' : 'display');
		my $rv = $upd_sth->execute($val, $desc, $category, $name); # Order matters
		mesg("Updating Block '$name' from Variable...");
		mesg($dbh->errstr."\n") if $dbh->err;
		if($rv eq '0E0'){	# Aparently we need to add the item.
			mesg("Failed\n");
			$ins_sth->execute($name, $val, $desc, $category);
			mesg("Attempting Insert of '$name' instead.\n");
			mesg($dbh->errstr."\n") if $dbh->err;
		} else{mesg("Done\n");}
		$remove .= ' OR ' if $remove;
		$remove .= 'name = ' . $dbh->quote($name);
	}
	$ins_sth->finish;
	$upd_sth->finish;
	$sth->finish;

	mesg("  Removing font vars...");
	$query = "DELETE FROM vars WHERE $remove";
	$rv = $dbh->do($query);
	mesg("done\n");
}

sub related_links {
	mesg("\nFixing related_links box\n");

	mesg("  Grabbing related_links box...");
	my $box = grab_box($dbh, 'related_links');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /\{VARS\}->\{autorelated\}/) {
		mesg("found. Leaving box alone.\n");
	} else {
		mesg("not found.\n  Fixing box...");
		$box =~ s/\{BLOCKS\}(->\{autorelated\})/\{VARS\}$1/;
		$box =~ s/chop\(/chomp(/;
		$box = "my \$db_name = \$S->{CONFIG}->{db_name};\n" . $box;
		$box =~ s/(introtext, bodytext, aid, tid)/$1, u.nickname AS nick/;
		$box =~ s/(FROM\s*=>\s*)\'stories\'/$1"stories s LEFT JOIN \$db_name.users u ON s.aid = u.uid"/;
		$box =~ s/\$data->\{aid\}/\$data->\{nick\}/g;
		$box =~ s/(my \@link_arr)/\$data->\{nick\} = \$S->\{UI\}->\{VARS\}->\{anon_user_nick\} if \$data->\{aid\} == -1;\n$1/;
		mesg("done\n");

		mesg("  Putting related_links back in...");
		update_box($dbh, 'related_links', $box);
		mesg("done\n");
	}
}


sub ad_box {
	mesg("\nUpdating ad_box for graphical ads\n");

	mesg("  Grabbing ad_box...");
	my $box = grab_box($dbh, 'ad_box');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /\$subdir/) {
		mesg("found. Leaving box alone.\n");
	} else {
		mesg("not found.\n  Fixing box...");
		$box =~ s/(\$content =~ s\/\%\%LINK)/my \$subdir = (\$adhash->\{example\} == 1) ? \'example\' : \$adhash->\{sponsor\};\nmy \$file_path = \$subdir . \'\/\' .  \$adhash->\{ad_file\};\n\n$1/i;
		$box =~ s/(\%\%FILE_PATH\%\%\/)\$adhash->\{ad_file\}/$1\$file_path/i;
		mesg("done\n");

		mesg("  Putting ad_box back in...");
		update_box($dbh, 'ad_box', $box);
		mesg("done\n");
	}
}

sub show_ad_box {
	mesg("\nUpdating show_ad box for graphical ads\n");

	mesg("  Grabbing show_ad box...");
	my $box = grab_box($dbh, 'show_ad');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /\{sponsor\}/) {
		mesg("found. Leaving box alone.\n");
	} else {
		mesg("not found.\n  Fixing box...");
		$box =~ s/\{sponser\}/\{sponsor\}/i;
		mesg("done\n");

		mesg("  Putting show_ad box back in...");
		update_box($dbh, 'show_ad', $box);
		mesg("done\n");
	}
}

sub diarysub_box {
	mesg("\nUpdating diarysub_box for Apache2\n");

	mesg("  Grabbing diarysub_box...");
	my $box = grab_box($dbh, 'diarysub_box');
	unless ($box) {
		mesg("not found. Skipping.\n");
		return;
	}
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /headers_out/) {
		mesg("found. Leaving box alone.\n");
	} else {
		mesg("not found.\n  Adding Apache2 support...");
		$box =~ s/header_out\(\s*\'location\'\s*,([^)]+)\)/headers_out->\{\'Location\'\} = $1/i;
		$box =~ s/header_out\(\s*\'Connection\'\s*,\s*\'close\'\s*\)/headers_out->\{\'Connection\'\} = \'close\'/i;
		mesg("done\n");

		mesg("  Putting diarysub_box back in...");
		update_box($dbh, 'diarysub_box', $box);
		mesg("done.\n");
	}
}

sub logout_box {
	mesg("\nUpdating logout_box for Apache2\n");

	mesg("  Grabbing logout_box...");
	my $box = grab_box($dbh, 'logout_box');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /headers_out/) {
		mesg("found. Leaving box alone.\n");
	} else {
		mesg("not found.\n  Adding Apache2 support...");
		$box =~ s/header_out\(\s*Location\s*=>\s*\$logout_url\s*\)/headers_out->\{\'Location\'\} = \"\$logout_url\"/i;
		mesg("done\n");

		mesg("  Putting logout_box back in...");
		update_box($dbh, 'logout_box', $box);
		mesg("done\n");
	}
}

sub auto_increment {
	mesg("\nMoving anonymous user\n");

	mesg("  Grabbing old nick and group...");
	$query = 'SELECT nickname, perm_group FROM users WHERE uid = -1';
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($nick, $group) = $sth->fetchrow_array;
	$sth->finish;
	unless ($nick) {
		mesg("not found.\n  Patch already applied. Skipping.\n");
		return;
	}
	mesg("done\n");

	mesg("  Updating var anon_user_nick...");
	$query = "UPDATE vars SET value = " . $dbh->quote($nick) . " WHERE name = 'anon_user_nick'";
	$rv = $dbh->do($query);
	mesg("done\n");

	unless ($rv) {
		mesg("  Error updating var. Not going to delete the row quite yet.\n");
		return;
	}

	mesg("  Updating var anon_user_group...");
	$query = "UPDATE vars SET value = " . $dbh->quote($group) . " WHERE name = 'anon_user_group'";
	$rv = $dbh->do($query);
	mesg("done\n");

	unless ($rv) {
		mesg("  Error updating var. Not going to delete the row quite yet.\n");
		return;
	}

	mesg("  Removing old anonymous user...");
	$query = 'DELETE FROM users WHERE uid = -1';
	$rv = $dbh->do($query);
	mesg("done\n");

	mesg("Converting users table to auto_increment...");
	$query = "ALTER TABLE users MODIFY uid INT(11) NOT NULL AUTO_INCREMENT";
	$dbh->do($query);
	mesg("done\n");
}

# utility functions follow from here
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
