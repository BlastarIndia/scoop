CREATE TABLE ops (
	op varchar(50) NOT NULL,
	template varchar(30) NOT NULL,
	func varchar(50),
	is_box int(1) default 0,
	enabled int(1) default 1,
	perm varchar(50) default '',
	description text,
	PRIMARY KEY (op)
);

UPDATE blocks SET block = CONCAT(block, ',\nedit_ops') WHERE bid = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms, ',edit_ops') WHERE perm_group_id = 'Superuser';

CREATE TABLE admin_tools (
	tool varchar(20) NOT NULL,
	pos int(2) NOT NULL,
	dispname varchar(60) NOT NULL,
	menuname varchar(60) NOT NULL,
	perm varchar(50) NOT NULL,
	func varchar(50) NOT NULL,
	is_box int(1) default 0,
	PRIMARY KEY (tool)
);

INSERT INTO admin_tools VALUES ('story',1,'Stories','New Story','story_admin','edit_story',0);
INSERT INTO admin_tools VALUES ('storylist',2,'Stories','Story List','story_list','list_stories',0);
INSERT INTO admin_tools VALUES ('editpoll',3,'Polls','New Poll','edit_polls','edit_polls',0);
INSERT INTO admin_tools VALUES ('listpolls',4,'Polls','Poll List','list_polls','admin_polls',0);
INSERT INTO admin_tools VALUES ('vars',5,'Vars','Site Controls','edit_vars','edit_vars',0);
INSERT INTO admin_tools VALUES ('blocks',6,'Blocks','Blocks','edit_blocks','edit_blocks',0);
INSERT INTO admin_tools VALUES ('topics',7,'Topics','Topics','edit_topics','edit_topics',0);
INSERT INTO admin_tools VALUES ('sections',8,'Sections','Sections','edit_sections','edit_sections',0);
INSERT INTO admin_tools VALUES ('special',9,'Special Pages','Special Pages','edit_special','edit_special',0);
INSERT INTO admin_tools VALUES ('boxes',10,'Boxes','Boxes','edit_boxes','edit_boxes',0);
INSERT INTO admin_tools VALUES ('groups',11,'Groups','Groups','edit_groups','edit_groups',0);
INSERT INTO admin_tools VALUES ('rdf',12,'RDF Feeds','RDF Feeds','rdf_admin','edit_rdfs',0);
INSERT INTO admin_tools VALUES ('cron',13,'Cron','Cron','cron_admin','edit_cron',0);
INSERT INTO admin_tools VALUES ('ads',14,'Advertising','Advertising','ad_admin','ad_admin_choice',0);
INSERT INTO admin_tools VALUES ('ops',15,'Ops','Ops','edit_ops','edit_ops',0);

UPDATE box SET content = 'my $content;\n\nmy @tools = sort { $a->{pos} <=> $b->{pos} } values %{ $S->{ADMIN_TOOLS} };\n\nforeach my $t (@tools) {\n	if ( $S->have_perm($t->{perm}) ) {\n		$content .= qq|\n	%%dot%% <a class="light" href="%%rootdir%%/admin/$t->{tool}">$t->{menuname}</a><br>|;\n	}\n}\n\nif ($S->have_perm(\'edit_user\')) {\n $content .= qq{<br>\n <FORM NAME="uedit" METHOD="GET" ACTION="%%rootdir%%/">\n Edit User:<BR>\n <INPUT TYPE="hidden" NAME="op" VALUE="user">\n <SMALL><INPUT TYPE="text" NAME="nick" VALUE="" SIZE=10>\n <INPUT TYPE="SUBMIT" NAME="tool" VALUE="prefs">\n <INPUT TYPE="SUBMIT" NAME="tool" VALUE="info">\n </SMALL></FORM>};\n}\n\nreturn \'\' unless $content;\n\nreturn $content;\n' WHERE boxid = 'admin_tools';
