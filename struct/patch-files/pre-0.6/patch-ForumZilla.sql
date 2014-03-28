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
