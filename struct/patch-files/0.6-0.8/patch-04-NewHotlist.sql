CREATE TABLE viewed_stories (
	uid INT(11) NOT NULL,
	sid VARCHAR(20) NOT NULL,
	lastseen int DEFAULT 0 NOT NULL,
	highest_idx int DEFAULT 0 NOT NULL,
	hotlisted TINYINT DEFAULT 0
);

INSERT INTO vars VALUES ("show_new_comments", "all", "Controls the saving of story view times and displaying of new comments. Possible values are all, hotlist, or never.", 'text', 'Comments,Stories');

UPDATE box SET content="if ($S->{HOTLIST} && $#{$S->{HOTLIST}} >= 0) {\n	my $box_content;\n\n	foreach my $sid (@{$S->{HOTLIST}}) {\n		my $stories = $S->getstories(\n			{-type => 'fullstory',\n			-sid => $sid});\n		my $story = $stories->[0];\n\n		my $show = $S->{UI}->{VARS}->{show_new_comments};\n		my $num_new = $S->new_comments_since_last_seen($sid) if ($show eq \"hotlist\" || $show eq \"all\");\n\n		my $end_s = ($story->{commentcount} == 1) ? '' : 's';\n		$box_content .= qq~%%dot%% <A CLASS=\"light\" HREF=\"|rootdir|/?op=displaystory;sid=$sid\">$story->{title}</a> ($story->{commentcount} comment$end_s~;\n		$box_content .= \", $num_new new\" if defined($num_new);\n		$box_content .= \")<BR>\";\n	}\n\n	my $title = \"$S->{NICK}'s Hotlist\";\n	return {title => $title, content => $box_content };\n}\n" WHERE boxid = "hotlist_box";

INSERT INTO blocks VALUES ('new_comment_marker','<FONT COLOR=\"#FF0000\"><B>!</B></FONT>',NULL,NULL);
