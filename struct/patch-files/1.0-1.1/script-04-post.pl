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

mesg("\nMoving pref default values from Site Controls to userpref definitions...\n");
# default_comment_order -> commentorder
$default = &grab_var($dbh,'default_comment_order');
$default = 'oldest' unless $default =~ /newest|oldest/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='commentorder'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_comment_order');
# default_comment_sort -> commentrating
$default = &grab_var($dbh,'default_comment_sort');
$default = 'dontcare' unless $default =~ /unrate_highest|highest|lowest|dontcare/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='commentrating'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_comment_sort');
# default_comment_view -> commenttype
$default = &grab_var($dbh,'default_comment_view');
$default = 'mixed' unless $default =~ /mixed|topical|editorial|all|none/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='commenttype'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_comment_view');
# default_hidingchoice -> hidingchoice
$default = &grab_var($dbh,'default_hidingchoice');
$default = 'untilrating' unless $default =~ /yes|no|untilrating/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='hidingchoice'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_hidingchoice');
# default_post_type -> posttype
$default = &grab_var($dbh,'default_post_type');
$default = 'auto' unless $default =~ /text|html|auto/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='posttype'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_post_type');
# default_sig_behavior -> sig_behavior
$default = &grab_var($dbh,'default_sig_behavior');
$default = 'retroactive' unless $default =~ /retroactive|sticky|none/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='sig_behavior'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_sig_behavior');
# default_textarea_cols -> textarea_cols
$default = &grab_var($dbh,'default_textarea_cols');
$default = '60' unless $default =~ /\d+/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='textarea_cols'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_textarea_cols');
# default_textarea_rows -> textarea_rows
$default = &grab_var($dbh,'default_textarea_rows');
$default = '20' unless $default =~ /\d+/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='textarea_rows'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_textarea_rows');
# spellcheck_default -> spellcheck_default
$default = &grab_var($dbh,'spellcheck_default');
$default = ($default) ? 'on' : 'off';
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='spellcheck_default'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'spellcheck_default');
# spellcheck_spelling -> speling
$default = &grab_var($dbh,'spellcheck_spelling');
$default = 'american' unless $default =~ /american|canadian|british/;
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='speling'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'spellcheck_spelling');
# topic_images_default -> show_topic
$default = &grab_var($dbh,'topic_images_default');
$default = ($default) ? 'on' : 'off';
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='show_topic'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'topic_images_default');
# user_theme_default -> theme
$default = &grab_var($dbh,'user_theme_default');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='theme'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'user_theme_default');
# default_comment_display -> commentmode & commentmode_overflow
$default = &grab_var($dbh,'default_comment_display');
# it seems that the code expected 'threaded' but the docs said 'thread'
# my mistake...
$default = 'threaded' if $default eq 'thread';
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='commentmode' OR prefname='commentmode_overflow'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'default_comment_display');
# cookie_expire
$default = &grab_var($dbh,'cookie_expire');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='cookie_expire'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'cookie_expire');
# maxstories
$default = &grab_var($dbh,'maxstories');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='maxstories'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'maxstories');
# maxtitles
$default = &grab_var($dbh,'maxtitles');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='maxtitles'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'maxtitles');
# imagedir
$default = &grab_var($dbh,'imagedir');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='imagedir'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'imagedir');
# upload_user_quota
$default = &grab_var($dbh,'upload_user_quota');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='upload_user_quota'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'upload_user_quota');
# upload_max_file_size
$default = &grab_var($dbh,'upload_max_file_size');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='upload_max_file_size'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
&delete_var($dbh,'upload_max_file_size');
# time_zone
$default = &grab_var($dbh,'time_zone');
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='time_zone'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;
# don't delete this var, as it's also the system time zone

mesg("\nFixing font prefs...\n");
my $font_tag = &grab_block($dbh,'norm_font');
my ($font_face, $font_size);
if ( $font_tag =~ /face="(.*?)"/ ) {
	$font_face = $1;
	$font_tag =~ s/$1/%%norm_font_face%%/;
} else {
	mesg("No font face set in block norm_font, skipping. To allow users to select their own font face however it is set, place the key |norm_font_face| where the font name(s) should appear. Don't forget to set the default value correctly in the Prefs Admin Tool\n");
}
if ( $font_tag =~ /size="(.*?)"/ ) {
	$font_size = $1;
	$font_tag =~ s/$1/%%norm_font_size%%/;
} else {
	mesg("No font size set in block norm_font, skipping. To allow users to select their own font size however it is set, place the key |norm_font_size| where the font size should appear. Don't forget to set the default value correctly in the Prefs Admin Tool\n");
}
&update_block($dbh,'norm_font',$font_tag);
# now update the defaults for the font size & face prefs if they were dealt with above
if ( $font_face ) {
	$query = qq{UPDATE pref_items SET default_value='$font_face' WHERE prefname='norm_font_face'};
	$sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
}
if ( $font_size ) {
	$query = qq{UPDATE pref_items SET default_value='$font_size' WHERE prefname='norm_font_size'};
	$sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
}


mesg("\nFixing displayed boxes pref...\n");

# first get a list of boxes that may be set in this pref
$query = qq{SELECT boxid FROM box WHERE user_choose='1'};
$sth = $dbh->prepare($query);
$sth->execute;
my @boxes = ();
while (my ($box) = $sth->fetchrow_array) {
	push (@boxes, $box);
}
$sth->finish;

# next set the default for the pref to all of those boxes, comma-separated
$default = join(',',@boxes);
$query = qq{UPDATE pref_items SET default_value='$default' WHERE prefname='displayed_boxes'};
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;

# next change the value of the userprefs that are set to be a list of boxes shown, 
# instead of boxes not shown
$query = qq{SELECT * from userprefs WHERE prefname='displayed_boxes'};
$sth = $dbh->prepare($query);
$sth->execute;
my %box_prefs;
while (my $row = $sth->fetchrow_hashref) {
	my @user_boxes = ();
	foreach my $option (@boxes) {
		next if $row->{prefvalue} =~ /$option/;
		push (@user_boxes, $option);
	}
	$box_prefs{$row->{uid}} = join(',',@user_boxes);
}
$sth->finish;
# now put the modified userprefs back in
foreach my $uid (keys %box_prefs) {
	$query = qq|UPDATE userprefs SET prefvalue='$box_prefs{$uid}' WHERE prefname='displayed_boxes' AND uid='$uid'|;
	$sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
}

mesg("\nFixing boxes to use new pref scheme... ");

# changes to whos_online, ad_box, and user_box
my $box_content;

$box_content = &grab_box($dbh,'ad_box');
unless ($box_content =~ /showad/) {
	$box_content = q{return '' if( $S->pref('showad') eq 'off' );
} . $box_content;
}
$box_content =~ s/Yes/on/;
&update_box($dbh,'ad_box',$box_content);
# ok, this box has changed quite a bit without the changes showing up in patches...
# so the only changes I'll make are the two pref-related ones.
mesg("ad_box");

$box_content = &grab_box($dbh,'user_box');
$box_content =~ s#interface/prefs#my/prefs/Interface#;
$box_content =~ s#interface/comments#my/prefs/Comments#;
&update_box($dbh,'user_box',$box_content);
mesg(", user_box");

$box_content = &grab_box($dbh,'whos_online');
$box_content =~ s#online_cloak}\)#online_cloak} eq 'on'\)#;
$box_content =~ s#interface/prefs#my/prefs/Interface#;
&update_box($dbh,'whos_online',$box_content);
mesg(", whos_online\n");

mesg("\nUpdating comment mode userprefs for all users...\n");

# first get the overflow values, those are the easiest
$query = qq|SELECT * from userprefs WHERE prefvalue = '+' AND prefname LIKE '%_to'|;
$sth = $dbh->prepare($query);
$sth->execute;
my $overflow_pref = $sth->fetchall_hashref('uid');
$sth->finish;
foreach my $uid (keys %{$overflow_pref}) {
	my $overflow_value = $overflow_pref->{$uid}->{prefname};
	$overflow_value =~ s/_to//;
	$overflow_value =~ s/comment_//;
	&insert_pref($dbh, $uid, 'commentmode_overflow', $overflow_value);
	&insert_pref($dbh, $uid, 'commentmode', 'use_overflow');
		# if they have a non-overflow value set, it'll get overridden
		# and if not, we don't want to mess them up
}
$query = qq|DELETE from userprefs WHERE prefvalue = '+' AND prefname LIKE '%_to'|;
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;

# next get the rest of the values
$query = qq|SELECT * from userprefs WHERE prefname LIKE '%_to'|;
$sth = $dbh->prepare($query);
$sth->execute;
my %mode_prefs;
my %overflow_number;
while ( my $c_mode = $sth->fetchrow_hashref() ) {
	if ( $c_mode->{prefvalue} > $overflow_number{$c_mode->{uid}} ) {
		$overflow_number{$c_mode->{uid}} = $c_mode->{prefvalue};
		$mode_prefs{$c_mode->{uid}} = $c_mode->{prefname};
		$mode_prefs{$c_mode->{uid}} =~ s/_to//;
		$mode_prefs{$c_mode->{uid}} =~ s/comment_//;
	}
}
foreach my $uid (keys %overflow_number) {
	&update_pref($dbh, $uid, 'commentmode', $mode_prefs{$uid});
	&insert_pref($dbh, $uid, 'commentmode_overflow_at', $overflow_number{$uid});
}

# have to patch the new_user_html (and description) so required prefs show up if used
mesg("Updating new_user_html block...\n");
my $new_user_html = &grab_block($dbh,'new_user_html');
$new_user_html =~ s/(<input type="submit")/%%required_prefs%%<br>$1/;
&update_block($dbh,'new_user_html',$new_user_html);
# and the description...
$query = "SELECT description FROM blocks WHERE bid='new_user_html'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($new_user_html_desc) = $sth->fetchrow_array;
$sth->finish;
$new_user_html_desc =~ s/(<\/dl>)$/ <dt>required_prefs<\/dt><dd>The controls for any user preferences marked as "required"<\/dd>$1/;
my $new_desc_q = $dbh->quote($new_user_html_desc);
$query = "UPDATE blocks SET description=$new_desc_q WHERE bid='new_user_html'";
$sth = $dbh->prepare($query);
$sth->execute;
$sth->finish;


# utility functions follow from here
sub insert_pref {
	my ($dbh, $uid, $pref, $value) = @_;
	my $q_uid = $dbh->quote($uid);
	my $q_pref = $dbh->quote($pref);
	my $q_value = $dbh->quote($value);
	my $query = "INSERT INTO userprefs VALUES ($q_uid, $q_pref, $q_value)";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	return ($dbh->errstr) ? $dbh->errstr : '';
}

sub update_pref {
	my ($dbh, $uid, $pref, $value) = @_;
	my $q_uid = $dbh->quote($uid);
	my $q_pref = $dbh->quote($pref);
	my $q_value = $dbh->quote($value);
	my $query = "UPDATE userprefs SET uid=$q_uid, prefname=$q_pref, prefvalue=$q_value WHERE uid=$q_uid AND prefname=$q_pref";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	return ($dbh->errstr) ? $dbh->errstr : '';
}

sub delete_var {
	my ($dbh, $id) = @_;
	my $query = "DELETE FROM vars WHERE name=" . $dbh->quote($id);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
}

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
