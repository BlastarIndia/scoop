#!/usr/bin/perl
use strict;
use DBI;

if ($ARGV[0] =~ /^--?h/) {
	print "usage: fix_urls.pl user pass database\n";
	exit;
}

my $db_user = $ARGV[0] || 'nobody';
my $db_host = 'localhost';
my $db_pass = $ARGV[1] || '';
my $db_port = 3306;
my $db_name = $ARGV[2] || 'scoop';

my %checksums = (
	user_box           => [ 'a4e91983b55f83ee88bc8933f56f9018', 'box'   ],
	menu_footer        => [ 'd3dc9c6158dda84c2df3056122090410', 'box'   ],
	older_list_box     => [ '098a2a9f909ddd770a16d8d2b34055a9', 'box'   ],
	admin_tools        => [ '96e05a9552d22b558c2048b352a7095b', 'box'   ],
	main_menu          => [ '8c9d61466809f03e14d6ccfb1eece849', 'box'   ],
	poll_box           => [ '90bf60c573d6f2e9cc0dcab4cc1e0b3f', 'box'   ],
	comment            => [ '16b74b2075b9fe54bb04e176139f2a3d', 'block' ],
	moderation_comment => [ '6570cded66f022d45fbbaae008f7ce90', 'block' ],
	scoop_intro        => [ 'a9886a9553823ea18abd69ce1126c5ac', 'block' ]
);

my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass);

$| = 1;     # turn buffering off

print "Scanning DB for changes...";
my %no_update;

my $box_query = "SELECT md5(content) FROM box WHERE boxid = ?";
my $block_query = "SELECT md5(block) FROM blocks WHERE bid = ?";

my $box_sth = $dbh->prepare($box_query);
my $block_sth = $dbh->prepare($block_query);

while (my($k, $v) = each %checksums) {
	my $sth = ($v->[1] eq 'box') ? $box_sth : $block_sth;
	$sth->execute($k);
	my ($sum) = $sth->fetchrow_array;
	if ($sum ne $v->[0]) {
		$no_update{$k} = $v->[1];
	}
}

$box_sth->finish;
$block_sth->finish;
print "done\n";

print "Loading SQL statements and making changes...\n";
while (my $l = <DATA>) {
	chomp($l);
	next unless $l;
	my ($b, $data) = split(/=/, $l, 2);
	unless ($no_update{$b}) {
		print "updating $checksums{$b}->[1] $b\n";
		$dbh->do($data);
	}
}
print "done\n\n";

$dbh->disconnect;

print "Finished updating all unchanged boxes and blocks. For the rest, you'll
need to manually edit them. Also, if you've written any other boxes or blocks
with links to others parts of scoop in them, you'll probably want to check them
for &'s instead of ;'s in the URL. The following were not updated because they
have been changed:\n\n";

while (my($name, $type) = each %no_update) {
	print "$type $name\n";
}

__DATA__
user_box=UPDATE box SET content = 'my $content;\nif ($S->{UID} > 0) {\n  if ($S->have_perm(\'moderate\')) {\n    my $new_stories = $S->_count_new_sub();\n    my $color = \'\';\n    my $c_end = \'\';\n    if ($new_stories) {\n       $color = \'<FONT COLOR="#FF0000"><B>\';\n       $c_end = \'</B></FONT>\';\n    }\n    $content = qq|\n    %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=modsub">Moderate Submissions</A> ($color$new_stories$c_end new)<BR>|;\n  }\n\n  if ($S->{TRUSTLEV} == 2 || $S->have_perm(\'super_mojo\')) {\n    $content .= qq{\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=search;type=comment;hidden_comments=show">Review Hidden Comments</A><BR>};\n  }\n  \n  my $urlnick = $S->urlify($S->{NICK});\n  my $diary_link = ( $S->{UI}->{VARS}->{use_diaries} ? \n		qq{ %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=section;section=Diary;user=diary_$S->{UID}">Your Diary</A><BR>} :\n		qq{} );\n\n  $content .= qq|\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=user;tool=info">User Info</A><BR>\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=search;type=comment_by;string=$urlnick">Your Comments</A><BR>\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=search;type=author;string=$urlnick">Your Stories</A><BR>\n      $diary_link\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=submitstory;section=Diary">New Diary Entry</A><BR>\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=user;tool=prefs">User Preferences</A><BR>\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=interface;tool=prefs">Display Preferences</A><BR>\n	  %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=interface;tool=comments">Comment Preferences</A><BR>\n      %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=logout">Logout $S->{NICK}</A><BR>|;\n\n    $title = "$S->{NICK}";\n} else {\n    $content = $S->{UI}->{BLOCKS}->{login_box};\n    $content =~ s/%%LOGIN_ERROR%%/$S->{LOGIN_ERROR}/;\n}\nreturn {content => $content, title => $title };\n' WHERE boxid = 'user_box'

menu_footer=UPDATE box SET content = 'my $submit = \'\';\nmy $acct = \'\';\n\nif ( $S->have_perm(\'story_post\') ) {\n    $submit = \'<A HREF="%%rootdir%%/?op=submitstory">submit story</A> |\';\n}\n\nif ($S->{UID} < 0) {\n    $acct = \'<A HREF="%%rootdir%%/?op=newuser">create account</A> |\';\n}\n\nmy $content = qq{\n%%norm_font%%\n$submit\n$acct\n<A HREF="%%rootdir%%/?op=special;page=faq">faq</A> |\n<A HREF="%%rootdir%%/?op=search">search</A>\n%%norm_font_end%%};\n\nreturn $content;\n' WHERE boxid = 'menu_footer'

older_list_box=UPDATE box SET content = 'my $section = $S->{CGI}->param(\'section\') || \'front\';\nmy $stories = [];\n\nif ($section eq \'front\') {\n    $stories = $S->getstories({-type => \'titlesonly\', -displaystatus => \'0\'});\n} elsif ($section eq \'__all__\') {\n    $stories = $S->getstories({-type => \'titlesonly\', -section => \'!Diary\'});\n} else {\n    $stories = $S->getstories({-type => \'titlesonly\', -section => $section});\n}\nmy $box_content;\n\nmy $date = undef;\nforeach my $story (@{$stories}) {\n    if (($story->{ftime} ne $date) || !$date) {\n        $date = $story->{ftime};\n        $box_content .= qq|\n	<P>\n                <B>$story->{ftime}</B>|;\n    }\n    $box_content .= qq|\n    <BR>%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=displaystory;sid=$story->{sid}">$story->{title}</A> ($story->{commentcount} comments)|;\n    \n	if ($S->have_perm(\'story_list\')) {\n        $box_content .= qq| [<A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=story;sid=$story->{sid}">edit</A>]|;\n    }\n}\n\nmy $offset = $S->{UI}->{VARS}->{maxstories} + $#{$stories};\nmy $search_url = qq{%%rootdir%%/?op=search;offset=$offset};\n$search_url .= \';section=\'.$section if ($section ne \'front\');\n\n$box_content .= qq|\n            <P>\n            <A CLASS="light" HREF="$search_url">Older Stories...</A>\n            </P>|;\nmy $return = {content => "%%smallfont%%$box_content%%smallfont_end%%"};\nif ($section ne \'front\' && $section ne \'__all__\') {\n    $return->{title} = $S->{SECTION_DATA}->{$section}->{title};\n} elsif ($section eq \'__all__\') {\n    $return->{title} = \'All Stories\';\n}\n\nreturn $return;\n' WHERE boxid = 'older_list_box'

admin_tools=UPDATE box SET content = 'my $content;\n\nif ($S->have_perm(\'story_admin\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=story">New Story</a><BR>|;\n}\nif ($S->have_perm(\'story_list\')) {\n	$content .= qq|	\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=storylist">Story List</a><BR>|;\n}\nif ($S->have_perm(\'edit_polls\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=editpoll">New Poll</a><BR>|;\n}\nif ($S->have_perm(\'list_polls\')) {\n	$content .= qq|\n                %%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=listpolls">Poll List</a><BR>|;\n}\nif ($S->have_perm(\'edit_vars\') || $S->have_perm(\'edit_blocks\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=blocks">Blocks</a><BR>\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=vars">Site Controls</a><BR>|;\n}\nif ($S->have_perm(\'edit_topics\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=topics">Topics</a><BR>|;\n}\nif ($S->have_perm(\'edit_sections\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=sections">Sections</a><BR>|;\n}\nif ($S->have_perm(\'edit_special\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=special">Special Pages</a><BR>|;\n}\nif ($S->have_perm(\'edit_boxes\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=boxes">Boxes</a><BR>|;\n}\nif ($S->have_perm(\'edit_templates\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=optemplates">Templates</a><BR>|;\n}\nif ($S->have_perm(\'edit_groups\')) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=groups">Groups</a><BR>|;\n}\nif ($S->have_perm(\'rdf_admin\') && $S->{UI}->{VARS}->{use_rdf_feeds}) {\n	$content .= qq|\n	%%dot%% <A CLASS="light" HREF="%%rootdir%%/?op=admin;tool=rdf">RDF Feeds</a><BR>|;\n}\n\nif ($S->have_perm(\'edit_user\')) {\n	$content .= qq{\n	<BR>\n	<FORM NAME="uedit" METHOD="GET" ACTION="%%rootdir%%/">\n	Edit User:<BR>\n	<INPUT TYPE="hidden" NAME="op" VALUE="user">\n	<SMALL><INPUT TYPE="text" NAME="nick" VALUE="" SIZE=10>\n	<INPUT TYPE="SUBMIT" NAME="tool" VALUE="prefs">\n	<INPUT TYPE="SUBMIT" NAME="tool" VALUE="info">\n	</small></form>};\n}\n\nreturn \'\' unless $content;\n\nreturn $content;\n' WHERE boxid = 'admin_tools'

main_menu=UPDATE box SET content = 'my $submit = \'\';\nmy $acct = \'\';\n\nif ( $S->have_perm(\'story_post\') ) {\n    $submit = qq{%%dot%% <A HREF="%%rootdir%%/?op=submitstory">submit story</A><BR>};\n}\nif ($S->{UID} < 0) {\n    $acct = \'%%dot%% <A HREF="%%rootdir%%/?op=newuser">create account</A><BR>\';\n}\n\nmy $content = qq{\n%%smallfont%%\n$submit\n$acct\n%%dot%% <A HREF="%%rootdir%%/?op=special;page=faq">faq</A><BR>\n%%dot%% <A HREF="%%rootdir%%/?op=search">search</A>\n%%smallfont_end%%};\n\nreturn $content;\n' WHERE boxid = 'main_menu'

poll_box=UPDATE box SET content = 'my $pollqid = shift @ARGS;\nmy $preview = 0;\n\nmy ($pollqid, $action) = $S->get_qid_to_show();\n$preview = 1 if ($action eq \'preview\');\nreturn \'\' if ($pollqid == 0);\n\nmy $poll_hash = $S->get_poll_hash( $pollqid, $action );\n\n# first get the poll form all set up except for the answers\nmy $poll_form = qq|\n	<!-- begin poll form -->\n	<FORM ACTION="%%rootdir%%/" METHOD="POST">\n    <INPUT TYPE="hidden" NAME="op" VALUE="view_poll">\n    <INPUT TYPE="hidden" NAME="qid" VALUE="$poll_hash->{\'qid\'}">\n    <INPUT type="hidden" name="ispoll" value="1">|;\n\n$poll_form .= "<b>$poll_hash->{\'question\'}</b><br>";\n\n# here is where all the answer fields get filled in\nmy $answer_array = $S->get_poll_answers($poll_hash->{\'qid\'}, $action);\n\n# now check if they have already voted or haven\'t logged in\nmy $row;\nif ( $S->_can_vote($poll_hash->{\'qid\'}) ) {\n    foreach $row ( @{$answer_array} ) {	\n        $poll_form .= qq|\n   	        <INPUT TYPE="radio" NAME="aid" VALUE="$row->{\'aid\'}"> $row->{\'answer\'}<BR>|;\n   	}\n} else {\n    my $total_votes = $poll_hash->{\'voters\'};\n\n    if($total_votes == 0) {\n        $total_votes = 1;  # so we don\'t get a divide by 0 error\n    }\n\n	$poll_form .= qq|\n		<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=0>|;\n\n	foreach $row ( @{$answer_array} ) {\n		my $percent = int($row->{\'votes\'} / $total_votes * 100);\n		$poll_form .= qq|\n			<TR>\n				<TD valign="top">%%norm_font%%%%dot%%%%norm_font_end%%</TD>\n				<TD valign="top">%%norm_font%%$row->{\'answer\'}%%norm_font_end%%</TD>\n				<TD valign="top">%%norm_font%% $percent% %%norm_font_end%%</TD>\n			</TR>|;\n   	}\n	$poll_form .= qq|\n		</TABLE>|;\n		\n}\n\n# get the # of comments\nmy $comment_num = $S->poll_comment_num($poll_hash->{\'qid\'});\n   \n# only show the vote button if they havn\'t voted\nif ( $S->_can_vote($poll_hash->{\'qid\'}) && ! $preview ) {\n	$poll_form .= qq|<BR><INPUT TYPE="submit" name="vote" VALUE="Vote">|;\n}\n\n\n# now finish up the form\nmy $op = $S->{CGI}->param(\'op\');\nmy $comm_disp = ($op ne \'displaystory\') ? \n	qq{\n	<TD>%%norm_font%%Votes: <b>$poll_hash->{\'voters\'}</b>%%norm_font_end%%</TD>\n	<TD ALIGN="center" WIDTH=15>%%norm_font%%|%%norm_font_end%%</TD>\n	<TD ALIGN="right">%%norm_font%% Comments: <b>$comment_num</b>%%norm_font_end%%</TD></TR>\n	} : \n	qq{\n	<TD COLSPAN="3" ALIGN="center">%%norm_font%%Votes: <b>$poll_hash->{\'voters\'}</b>%%norm_font_end%%</TD>\n	};\n\n$poll_form .= qq{\n	</FORM>\n	<!-- end poll form -->\n	<P>\n	%%norm_font%%\n    <TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 ALIGN="center">\n	<TR>\n		$comm_disp\n	<TR> };\n\nif( $preview ) {\n    $poll_form .= qq{\n	<TD>%%norm_font%%Results%%norm_font_end%%</TD>\n	<TD ALIGN="center" WIDTH=15>%%norm_font%%|%%norm_font_end%%</TD>\n    <TD ALIGN="right">%%norm_font%% Other Polls%%norm_font_end%%</TD></TR>\n	};\n\n} else {\n    $poll_form .= qq{\n	<TD>%%norm_font%%<a href="%%rootdir%%/?op=view_poll;qid=$poll_hash->{\'qid\'}">Results</a>%%norm_font_end%%</TD>\n	<TD ALIGN="center" WIDTH=15>%%norm_font%%|%%norm_font_end%%</TD>\n    <TD ALIGN="right">%%norm_font%% <a href="%%rootdir%%/?op=search;type=polls;search=Search">Other Polls</a>%%norm_font_end%%</TD></TR>\n	};\n}\n\n$poll_form .= qq{\n	</TABLE>\n	%%norm_font_end%%\n	<!-- end poll content -->};\n\n## don\'t forget to tell them its a poll preview if it is\nif( $preview ) {\n	$title = "Poll Preview";\n}\n\nif ($poll_form) {\n	return {content => qq{%%norm_font%%$poll_form%%norm_font_end%%}, title => $title};\n} else {\n	return \'\';\n}\n' WHERE boxid = 'poll_box'

comment=UPDATE blocks SET block = '<!-- start comment -->\n<TABLE CELLPADDING=1 CELLSPACING=0 BORDER=0 BGCOLOR="#006699">\n  <TR>\n    <TD width="100%">\n      <TABLE CELLPADDING=2 CELLSPACING=0 BORDER=0 BGCOLOR="%%comment_head_bg%%" width="100%">\n        <TR>\n          <TD WIDTH="100%"><A NAME="%%cid%%"></A>\n          %%norm_font%%<B>%%subject%%</B> %%score%%</A> (<A CLASS="light" HREF="%%rootdir%%?op=comments;sid=%%sid%%;cid=%%cid%%#%%cid%%">#%%cid%%</A>)%%norm_font_end%% <BR>\n          %%norm_font%%by %%name%% %%email%% on %%date%%<BR>%%user_info%% %%url%%%%norm_font_end%%\n          </TD>\n        </TR>\n      </TABLE>\n    </TD>\n  </TR>\n</TABLE>\n<BR>\n<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0>\n  <TR>\n    <TD>\n    %%norm_font%%%%comment%%<BR>%%sig%%<BR>%%actions%%%%norm_font_end%%\n    </TD>\n  </TR>\n</TABLE>\n<BR><BR>\n%%norm_font%%%%replies%%%%norm_font_end%%\n\n<!-- end comment -->\n\n' WHERE bid = 'comment'

moderation_comment=UPDATE blocks SET block = '<!-- start comment -->\n\n<TABLE CELLPADDING=1 CELLSPACING=0 BORDER=0 BGCOLOR="#FF0000">\n  <TR>\n    <TD width="100%">\n      <TABLE CELLPADDING=2 CELLSPACING=0 BORDER=0 BGCOLOR="%%comment_head_bg%%" width="100%">\n        <TR>\n          <TD WIDTH="100%"><A NAME="%%cid%%"></A>\n          %%norm_font%%<B>%%subject%%</B> %%score%%</A> (<A CLASS="light" HREF="%%rootdir%%?op=comments;sid=%%sid%%;cid=%%cid%%#%%cid%%">#%%cid%%</A>)%%norm_font_end%% <BR>\n          %%norm_font%%by %%name%% %%email%% on %%date%%<BR>%%user_info%% %%url%%%%norm_font_end%%\n          </TD>\n        </TR>\n      </TABLE>\n    </TD>\n  </TR>\n</TABLE>\n<BR>\n<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0>\n  <TR>\n    <TD>\n    %%norm_font%%%%comment%%<BR>%%sig%%<BR>%%actions%%%%norm_font_end%%\n    </TD>\n  </TR>\n</TABLE>\n<BR><BR>\n%%norm_font%%%%replies%%%%norm_font_end%%\n\n<!-- end comment -->\n\n' WHERE bid = 'moderation_comment'

scoop_intro=UPDATE blocks SET block = '<TABLE WIDTH="100%" BORDER=1 CELLPADDING=2 CELLSPACING=0>\n	<TR>\n		<TD BGCOLOR="#006699">\n			%%box_title_font%%Where to learn about Scoop%%box_title_font_end%%\n		</TD>\n	</TR>\n	<TR>\n		<TD>\n			%%norm_font%%\nHoly Crap! You have your own <A HREF="http://scoop.kuro5hin.org">Scoop</A> site now. Well, there\'s too many features for me to explain right here, but I can give you some places to look for help and whatnot.\n<P>\nThe main development site is at <A HREF="http://scoop.kuro5hin.org">scoop.kuro5hin.org</A>. This contains links to all the other stuff, so poke around a little.\n<P>\nFor immediate help and assistance from the Scoop code monkeys, join the <A HREF="http://sourceforge.net/mail/?group_id=4901">scoop-help mailing list</A>. This is practically a requirement for a pleasant Scoop administrative experience, since the docs kind of suck right now.\n<P>\nSpeaking of docs, there\'s a start at Sourceforge: <A HREF="http://sourceforge.net/docman/display_doc.php?docid=100&group_id=4901">The Scoop Admin\'s Guide</A>. Not complete yet, but it might help.\n<P>\nOther things of note: \n<UL>\n<LI> Many Scoop developers can often be found on IRC, channel #kuro5hin at kuro5hin.ircnetworks.net.\n<LI> The main Sourceforge page is <A HREF="http://sourceforge.net/project/?group_id=4901">here</A>\n<LI> The latest code is always <A HREF="http://sourceforge.net/cvs/?group_id=4901">in CVS</A>\n<LI> You can look at a convenient <A HREF="http://scoop.kuro5hin.org/?op=special;page=sites">list of other Scoop sites</A> to see what folks are doing with it			\n</UL>\n			%%norm_font_end%%\n		</TD>\n	</TR>\n</TABLE>\n<P>\n' WHERE bid = 'scoop_intro'
