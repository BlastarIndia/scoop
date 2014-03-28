INSERT INTO vars (name,value,description)  VALUES ('default_comment_sort', 'dontcare', 'This defines the default comment sorting by rating, it needs to be one of: \'unrate_highest\' \'highest\' \'lowest\' \'dontcare\''), ('default_comment_view', 'mixed', 'This defines the default comment type to view, it needs to be one of: \'mixed\' \'topical\' \'editorial\' \'all\''), ('default_comment_order', 'newest', 'This defines the default comment ordering by time, it needs to be one of: \'newest\' \'oldest\''), ('default_comment_display', 'thread', 'This sets the default comment display mode, it needs to be one of: \'nested\' \'flat\' \'minimal\' \'thread\''); 
INSERT INTO blocks VALUES ('opcodes','blank,\r\npoll_vote,\r\nmodsub,\r\nsubmitstory,\r\nadmin,\r\ndisplaystory,\r\nview_poll,\r\npoll_list,\r\ncomments,\r\nnewuser,\r\nspecial,\r\nolderlist,\r\nsearch,\r\ninterface,\r\nuser,\r\nsection,\r\nconfirmpass,\r\nlogout,\r\ndefault,\r\nfz,\r\nfzdisplay',NULL,NULL);
INSERT INTO blocks VALUES ('rss_template','<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n\r\n<rdf:RDF\r\nxmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\r\nxmlns:fz=\"http://www.zapogee.com/rdf/forumzilla/\"\r\n>\r\n\r\n%%BOX,fzdescribe%%\r\n\r\n</rdf:RDF>',NULL,NULL);
INSERT INTO blocks VALUES ('fz_navigation_url','%%site_url%%%%rootdir%%/?op=blank',NULL,NULL);
INSERT INTO blocks VALUES ('fz_ad_url','%%site_url%%%%rootdir%%/?op=blank',NULL,NULL);
INSERT INTO blocks VALUES ('blank_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%slogan%%</TITLE>\r\n</HEAD>\r\n<BODY BGCOLOR=\"#FFFFFF\"></body>\r\n</html>',NULL,NULL);
INSERT INTO blocks VALUES ('empty_box','%%content%%',NULL,NULL);
INSERT INTO blocks VALUES ('fzdisplay_template','<html>\r\n<head><title>%%slogan%%</title></head>\r\n<body bgcolor=\"#EEEEEE\">\r\n<table width=\"80%\" align=\"center\" cellpadding=0 cellspacing=0 bgcolor=\"#000000\" border=0>\r\n<tr><td>\r\n<table width=\"100%\" align=\"center\" cellpadding=10 cellspacing=0 bgcolor=\"#ffffff\" border=0>\r\n<tr><td>\r\n%%BOX,fzdisplay%%</center>\r\n</td></tr>\r\n</table>\r\n</td></tr>\r\n</table>\r\n</body>\r\n</html>',NULL,NULL);
INSERT INTO blocks VALUES ('rss_box','<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n\r\n<rdf:RDF\r\nxmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\r\nxmlns:fz=\"http://www.zapogee.com/rdf/forumzilla/\"\r\n>\r\n\r\n%%BOX,fzdescribe%%\r\n\r\n</rdf:RDF>',NULL,NULL);
INSERT INTO vars VALUES ('use_db_cache','0','Cache DB queries? DO NOT USE ME!!!! I AM VERY DANGEROUS AND BROKEN!!');
INSERT INTO vars VALUES ('db_cache_max','1M','Maximum size for DB query cache. DO NOT USE ME!!!! I AM VERY DANGEROUS AND BROKEN!!');
INSERT INTO vars VALUES ('site_url','http://www.mysite.com/','Enter the base url for your site above, excluding rootdir!');
INSERT INTO box VALUES ('fzdescribe','ForumZilla Support code','my $action = $S->{CGI}->param(\'action\');\r\nmy $page;\r\n\r\nif ($action eq \'describestory\') {\r\n    $page = $S->fzDescribeStory();\r\n} else {\r\n    $page = $S->fzDescribeForum();\r\n}\r\n\r\nreturn {\'content\'=>$page};','This is the interface to the FormZilla lib, to support ForumZilla. See http://www.zapogee.com/forumzilla/docs/server-howto.html for more','empty_box');
INSERT INTO box VALUES ('fzdisplay','ForumZilla Support code','my $action = $S->{CGI}->param(\'action\'); \r\nmy $sid = $S->{CGI}->param(\'sid\');\r\nmy $cid = $S->{CGI}->param(\'cid\');\r\nmy $pid = $S->{CGI}->param(\'pid\');\r\n\r\nmy $page; \r\n\r\nif ($action eq \'story\') {\r\n	$page = $S->displaystory($sid)\r\n} elsif ($action eq \'comment\') { \r\n	$page = $S->display_comments($sid, $pid, \'alone\', $cid);\r\n} \r\n\r\nreturn {\'content\'=>$page};','This is the interface to display stories and comments in FormZilla. See http://www.zapogee.com/forumzilla/docs/server-howto.html for more','empty_box');
INSERT INTO templates VALUES ('blank_template','blank');
INSERT INTO templates VALUES ('rss_template','fz');
INSERT INTO templates VALUES ('fzdisplay_template','fzdisplay');
# patch to mysql db to add saving of the register e-mail
ALTER TABLE users ADD origemail VARCHAR(50) AFTER realemail;
UPDATE users SET origemail = realemail;
INSERT INTO vars VALUES ('enable_story_digests','1','1 to be able to email digests, 0 otherwise');
ALTER TABLE commentcodes MODIFY name VARCHAR(32);
ALTER TABLE displaycodes MODIFY name VARCHAR(32);
ALTER TABLE pollanswers MODIFY qid VARCHAR(20) DEFAULT '' NOT NULL, MODIFY answer VARCHAR(255);
ALTER TABLE pollquestions MODIFY qid VARCHAR(20) DEFAULT '' NOT NULL, MODIFY question VARCHAR(255) DEFAULT '' NOT NULL;
ALTER TABLE pollvoters MODIFY qid VARCHAR(20) DEFAULT '' NOT NULL, MODIFY id VARCHAR(35) DEFAULT '' NOT NULL;
ALTER TABLE statuscodes MODIFY name VARCHAR(32);
ALTER TABLE topics MODIFY tid VARCHAR(20) DEFAULT '' NOT NULL, MODIFY image VARCHAR(30), MODIFY alttext VARCHAR(40);
ALTER TABLE vars MODIFY name VARCHAR(32) DEFAULT '' NOT NULL, MODIFY value VARCHAR(127), MODIFY description VARCHAR(255);
INSERT INTO blocks VALUES ('readmore_txt','Full Story',NULL,NULL);
INSERT INTO blocks VALUES ('no_body_txt','Comments >>',NULL,NULL);

INSERT INTO blocks VALUES ('box_title_bg','#006699',NULL,NULL);
INSERT INTO blocks VALUES ('comment_head_bg','#eeeeee',NULL,NULL);
INSERT INTO blocks VALUES ('dept_font','<FONT FACE=\"arial, helvetica, sans-serif\" SIZE=2>',NULL,NULL);
INSERT INTO blocks VALUES ('pendingstory_bg','#c0c0c0',NULL,NULL);
INSERT INTO blocks VALUES ('diary_submission_message','<FONT SIZE=\"+1\">Your new entry has been posted. Enjoy!</FONT>',NULL,NULL);
INSERT INTO blocks VALUES ('poll_guidelines','These are poll guidelines',NULL,NULL);
INSERT INTO blocks VALUES ('sectiononlystory_bg','#eeeeee',NULL,NULL);
INSERT INTO blocks VALUES ('section_links','%%norm_font%%  \r\n  <A HREF=\"%%rootdir%%/\">Front Page</A> \r\n  \xb7\r\n  <A HREF=\"%%rootdir%%/?op=section;section=__all__\">Everything</A> \r\n  \xb7\r\n  <A HREF=\"%%rootdir%%/?op=section;section=news\">News</A> \r\n  \xb7\r\n  <A HREF=\"%%rootdir%%/?op=section;section=Diary\">Diaries</A>\r\n%%norm_font_end%%',NULL,NULL);
INSERT INTO blocks VALUES ('smallfont','<FONT FACE=\"arial, Helvetica, Sans-Serif\" SIZE=2>',NULL,NULL);
INSERT INTO blocks VALUES ('smallfont_end','</FONT>',NULL,NULL);
INSERT INTO blocks VALUES ('story_mod_bg','#EEEEEE',NULL,NULL);
INSERT INTO blocks VALUES ('story_nav_bg','#EEEEEE',NULL,NULL);
INSERT INTO blocks VALUES ('submittedstory_bg','#c6dae4',NULL,NULL);
INSERT INTO blocks VALUES ('title_bgcolor','#EEEEEE',NULL,NULL);
INSERT INTO blocks VALUES ('undisplayedstory_bg','#c0c0c0',NULL,NULL);
INSERT INTO blocks VALUES ('scoop_intro','<TABLE WIDTH=\"100%\" BORDER=1 CELLPADDING=2 CELLSPACING=0>\r\n	<TR>\r\n		<TD BGCOLOR=\"#006699\">\r\n			%%box_title_font%%Where to learn about Scoop%%box_title_font_end%%\r\n		</TD>\r\n	</TR>\r\n	<TR>\r\n		<TD>\r\n			%%norm_font%%\r\nHoly Crap! You have your own <A HREF=\"http://scoop.kuro5hin.org\">Scoop</A> site now. Well, there\'s too many features for me to explain right here, but I can give you some places to look for help and whatnot.\r\n<P>\r\nThe main development site is at <A HREF=\"http://scoop.kuro5hin.org\">scoop.kuro5hin.org</A>. This contains links to all the other stuff, so poke around a little.\r\n<P>\r\nFor immediate help and assistance from the Scoop code monkeys, join the <A HREF=\"http://sourceforge.net/mail/?group_id=4901\">scoop-help mailing list</A>. This is practically a requirement for a pleasant Scoop administrative experience, since the docs kind of suck right now.\r\n<P>\r\nSpeaking of docs, there\'s a start at Sourceforge: <A HREF=\"http://sourceforge.net/docman/display_doc.php?docid=100&group_id=4901\">The Scoop Admin\'s Guide</A>. Not complete yet, but it might help.\r\n<P>\r\nOther things of note: \r\n<UL>\r\n<LI> Many Scoop developers can often be found on IRC, channel #kuro5hin at kuro5hin.ircnetworks.net.\r\n<LI> The main Sourceforge page is <A HREF=\"http://sourceforge.net/project/?group_id=4901\">here</A>\r\n<LI> The latest code is always <A HREF=\"http://sourceforge.net/cvs/?group_id=4901\">in CVS</A>\r\n<LI> You can look at a convenient <A HREF=\"http://scoop.kuro5hin.org/?op=special&page=sites\">list of other Scoop sites</A> to see what folks are doing with it			\r\n</UL>\r\n			%%norm_font_end%%\r\n		</TD>\r\n	</TR>\r\n</TABLE>\r\n<P>',NULL,NULL);


INSERT INTO vars VALUES ('auto_post_alert','1','When this is 1 local_email gets mailed everytime a story is auto_posted.');
INSERT INTO vars VALUES ('use_auto_post','0','If this is 1 stories will be automatically posted given a metric of the avg. scores of the comments to that story + their current score');
INSERT INTO vars VALUES ('allow_ballot_stuffing','0','If this var is 1, allow editors to set how many votes a poll answer has recieved when creating or editing
the poll.  Users can never set how many votes.');
INSERT INTO vars VALUES ('auto_post_frontpage','4','This is the value needed for a story to be automatically posted to the front page.  This is not sum of moderation to the story, but an average.  See use_auto_post for more description.');
INSERT INTO vars VALUES ('auto_post_section','3.25','This is the value needed for a story to be automatically posted to its section page.  See use_auto_post for more description.');
INSERT INTO vars VALUES ('max_intro_words','0','This is the maximum number of words allowed in the introtext of an article.  Set to 0 to disable.  If they try to post a story with more than this number of words in the intro, it doesn\'t let them, and tells them to get it under this number.');
INSERT INTO vars VALUES ('max_intro_chars','0','This is the maximum number of characters allowed in the introtext of an article.  Set to 0 to disable.  If they try to post a story with more than this number of characters in the intro, it doesn\'t let them, and tells them to keep it under this number.');
INSERT INTO vars VALUES ('title_font_end','</B></FONT>','end font tag for story titles.  will be changed to a block soon');
INSERT INTO vars VALUES ('box_title_font_end','</B></FONT>','end font tag forbox titles.  Will be moved to a block soon');

INSERT INTO box VALUES ('section_title','null','my $content = \'Latest News\';\r\n\r\nmy $op = $S->{CGI}->param(\'op\');\r\n\r\nif ($op eq \'section\') {\r\n  my $section = $S->{CGI}->param(\'section\');\r\n  $content = $S->{SECTION_DATA}->{$section}->{title} || \'All Stories\';\r\n}\r\n\r\nreturn {\'content\'=> \"%%title_font%%$content%%title_font_end%%\" };','Display title of currentsection','blank_box');

INSERT INTO box VALUES ('show_comment_raters','Others have rated this comment as follows:','my $content = qq{\r\n <table width=\"100%\" border=0 cellpadding=2 cellspacing=0>};\r\n\r\nmy $cid = $S->{CGI}->param(\'cid\');\r\nmy $sid = $S->{CGI}->param(\'sid\');\r\n\r\nmy $f_cid = $S->{DBH}->quote($cid);\r\nmy $f_sid = $S->{DBH}->quote($sid);\r\n\r\n#Check for hidden\r\nmy ($rv, $sth) = $S->db_select({\r\n    WHAT => \'points\',\r\n FROM => \'comments\',\r\n   WHERE => qq{sid = $f_sid AND cid = $f_cid}});\r\n\r\nmy $points = $sth->fetchrow();\r\n$sth->finish();\r\n\r\nif (($points < $S->{UI}->{VARS}->{rating_min}) && ($S->{TRUSTLEV} != 2)) {\r\n  return \'\';\r\n}\r\n\r\nmy ($rv, $sth) = $S->db_select({\r\n WHAT => \'uid, rating\',\r\n    FROM => \'commentratings\',\r\n WHERE => qq{sid = $f_sid AND cid = $f_cid}});\r\n\r\nmy $zeros = 0;\r\n\r\nwhile (my $rating = $sth->fetchrow_hashref()) {\r\n  my $user = $S->user_data($rating->{uid});\r\n \r\n    if (($rating->{\'rating\'} < $S->{UI}->{VARS}->{rating_min}) && ($S->{TRUSTLEV} != 2)) {\r\n      $zeros++;\r\n   } else {\r\n$content .= qq{\r\n         <tr>\r\n            <td>%%norm_font%%<A HREF=\"%%rootdir%%/?op=user;tool=info;uid=$rating->{uid}\">$user->{nickname}</A>%%norm_font_end%%</td>\r\n          <td>%%norm_font%%$rating->{rating}%%norm_font_end%%</td>\r\n          </tr>};\r\n }\r\n}\r\n\r\n$sth->finish();\r\n\r\nif ($zeros) {\r\n    my $word = ($zeros == 1) ? \"Rating\" : \"Ratings\";\r\n    \r\n$content .= qq{\r\n     <tr>\r\n            <td colspan=2>%%norm_font%%Zero $word: $zeros%%norm_font_end%%</td>\r\n       </tr>};\r\n}\r\n\r\n$content .= qq{\r\n    </table>};\r\n\r\nreturn {\'content\' => $content};','Display who rated a comment what','');

# now clean up old unneeded vars and blocks '
delete from vars where name like "%_bg%";
delete from blocks where bid = 'fortune_box';
delete from blocks where bid = 'commentswarning';
delete from blocks where bid = 'mainmenu';
delete from blocks where bid = 'moderation';
delete from blocks where bid = 'moderation_guidelines';
delete from blocks where bid = 'user_box';
delete from blocks where bid = 'recent_news_box';

INSERT INTO vars VALUES ('max_rdf_intro','15','This is the maximum number of words allowed in the rdf intro description.  Everything over this will be cut off (not deleted, just not shown), and replaced by a \'...\'');
INSERT INTO vars VALUES ('use_diaries','1','If this is 0 nobody will be able to post diaries, or view a users\' diary.');
