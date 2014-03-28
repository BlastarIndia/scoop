# First add the templates
INSERT INTO blocks VALUES ('story_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%sitename%% || %%subtitle%%</TITLE>\r\n</HEAD>\r\n<BODY bgcolor=\"#FFFFFF\" text=\"#000000\" link=\"#006699\" vlink=\"#003366\">\r\n\r\n%%header%%\r\n\r\n<!-- Main layout table -->\r\n<TABLE BORDER=0 WIDTH=\"99%\" ALIGN=\"center\" CELLPADDING=0 CELLSPACING=10>\r\n	<!-- Main page block -->\r\n	<TR>\r\n		<!-- Left boxes column -->\r\n		<TD VALIGN=\"top\" WIDTH=\"15%\" BGCOLOR=\"#EEEEEE\">\r\n\r\n			%%__box__main_menu%%\r\n			%%__box__hotlist_box%%\r\n			%%__box__user_box%%\r\n			%%__box__admin_tools%%\r\n			%%__box__related_links%%\r\n			%%__box__comment_controls%%\r\n		\r\n		</TD>\r\n		<!-- X Left boxes column -->\r\n		\r\n		<!-- Center content section -->\r\n		<TD VALIGN=\"top\" width=\"85%\">\r\n		<!-- Story stuff -->\r\n		<TABLE WIDTH=\"100%\" BORDER=0 CELLPADDING=4 CELLSPACING=0>\r\n			<TR>\r\n				<TD VALIGN=\"top\">%%STORY%%</TD>\r\n				<TD VALIGN=\"top\">%%__box__poll_box%%<P>%%BOXES%%</TD>\r\n			</TR>\r\n		</TABLE>\r\n		<!-- X story stuff -->\r\n		<!-- comments -->\r\n		%%CONTENT%%\r\n		%%COMMENTS%%\r\n		<!-- X comments -->\r\n		</TD>\r\n		<!-- X center content section -->\r\n		\r\n	</TR>\r\n	<!-- X main page block -->\r\n</TABLE>\r\n<!-- X Main layout table -->\r\n<P>\r\n%%footer%%\r\n<P>\r\n<CENTER>%%__box__menu_footer%%</CENTER>\r\n</BODY>\r\n</HTML>\r\n',NULL,NULL);
INSERT INTO blocks VALUES ('default_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%sitename%% || %%subtitle%%</TITLE>\r\n</HEAD>\r\n<BODY bgcolor=\"#FFFFFF\" text=\"#000000\" link=\"#006699\" vlink=\"#003366\">\r\n\r\n%%header%%\r\n\r\n<!-- Main layout table -->\r\n<TABLE BORDER=0 WIDTH=\"99%\" ALIGN=\"center\" CELLPADDING=0 CELLSPACING=10>\r\n	<!-- Main page block -->\r\n	<TR>\r\n		<!-- Left boxes column -->\r\n		<TD VALIGN=\"top\" WIDTH=\"15%\" BGCOLOR=\"#EEEEEE\">\r\n\r\n			%%__box__main_menu%%\r\n			%%__box__hotlist_box%%\r\n			%%__box__user_box%%\r\n			%%__box__admin_tools%%\r\n		\r\n		</TD>\r\n		<!-- X Left boxes column -->\r\n		\r\n		<!-- Center content section -->\r\n		<TD VALIGN=\"top\" width=\"60%\">\r\n		\r\n			%%CONTENT%%\r\n		\r\n		</TD>\r\n		<!-- X center content section -->\r\n		\r\n	</TR>\r\n	<!-- X main page block -->\r\n</TABLE>\r\n<!-- X Main layout table -->\r\n<P>\r\n%%footer%%\r\n<P>\r\n<CENTER>%%__box__menu_footer%%</CENTER>\r\n</BODY>\r\n</HTML>\r\n',NULL,NULL);
INSERT INTO blocks VALUES ('submit_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%sitename%% || %%subtitle%%</TITLE>\r\n</HEAD>\r\n<BODY bgcolor=\"#FFFFFF\" text=\"#000000\" link=\"#006699\" vlink=\"#003366\">\r\n\r\n%%header%%\r\n\r\n<!-- Main layout table -->\r\n<TABLE BORDER=0 WIDTH=\"99%\" ALIGN=\"center\" CELLPADDING=0 CELLSPACING=10>\r\n	<!-- Main page block -->\r\n	<TR>\r\n		<!-- Left boxes column -->\r\n		<TD VALIGN=\"top\" WIDTH=\"15%\" BGCOLOR=\"#EEEEEE\">\r\n\r\n			%%__box__main_menu%%\r\n			%%__box__hotlist_box%%\r\n			%%__box__user_box%%\r\n			%%__box__admin_tools%%\r\n		\r\n		</TD>\r\n		<!-- X Left boxes column -->\r\n		\r\n		<!-- Center content section -->\r\n		<TD VALIGN=\"top\" width=\"60%\">\r\n			%%STORY%%\r\n			%%CONTENT%%\r\n		\r\n		</TD>\r\n		<!-- X center content section -->\r\n		\r\n	</TR>\r\n	<!-- X main page block -->\r\n</TABLE>\r\n<!-- X Main layout table -->\r\n<P>\r\n%%footer%%\r\n<P>\r\n<CENTER>%%__box__menu_footer%%</CENTER>\r\n</BODY>\r\n</HTML>\r\n',NULL,NULL);
 
#
# Table structure for table 'templates'
#
CREATE TABLE templates (
  template_id varchar(30) DEFAULT '' NOT NULL,
  opcode varchar(50) DEFAULT '' NOT NULL,
  PRIMARY KEY (opcode)
);

#
# Dumping data for table 'templates'
#

INSERT INTO templates VALUES ('index_template','default');
INSERT INTO templates VALUES ('story_template','displaystory');
INSERT INTO templates VALUES ('default_template','confirmpass');
INSERT INTO templates VALUES ('default_template','admin');
INSERT INTO templates VALUES ('default_template','comments');
INSERT INTO templates VALUES ('default_template','interface');
INSERT INTO templates VALUES ('index_template','logout');
INSERT INTO templates VALUES ('default_template','modsub');
INSERT INTO templates VALUES ('default_template','newuser');
INSERT INTO templates VALUES ('default_template','olderlist');
INSERT INTO templates VALUES ('default_template','poll_list');
INSERT INTO templates VALUES ('default_template','poll_vote');
INSERT INTO templates VALUES ('default_template','search');
INSERT INTO templates VALUES ('default_template','section');
INSERT INTO templates VALUES ('default_template','special');
INSERT INTO templates VALUES ('submit_template','submitstory');
INSERT INTO templates VALUES ('default_template','user');
INSERT INTO templates VALUES ('default_template','view_poll');
