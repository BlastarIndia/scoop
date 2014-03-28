# Table structure for table 'ad_info'
#

CREATE TABLE ad_info (
  ad_id int(11) NOT NULL auto_increment,
  ad_templ varchar(30) NOT NULL default '',
  ad_file varchar(255) default NULL,
  ad_url varchar(255) default NULL,
  ad_text1 text,
  ad_text2 text,
  views_left int(11) default '0',
  last_day date default NULL,
  perpetual int(1) default '0',
  last_seen datetime default NULL,
  sponser int(6) NOT NULL default '0',
  active int(1) default '0',
  example int(1) default '0',
  PRIMARY KEY  (ad_id),
  KEY seen_active (active,last_seen,ad_templ)
) TYPE=MyISAM;

#
# Dumping data for table 'ad_info'
#

INSERT INTO ad_info VALUES (1,'basic_banner_ad_template','damn-freebsd.gif','http://www.kuro5hin.org','This is ad text 1','This is ad text 2',0,NULL,0,NULL,1,0,1);
INSERT INTO ad_info VALUES (2,'basic2_banner_ad_template','damnlinux-black.gif','http://scoop.kuro5hin.org','This is ad text 1','This is ad text 2',0,NULL,0,NULL,1,0,1);

#
# Table structure for table 'ad_types'
#

CREATE TABLE ad_types (
  type_name varchar(30) NOT NULL default '',
  short_desc varchar(255) NOT NULL default '',
  submit_instructions text,
  example_file varchar(255) default NULL,
  example_url varchar(255) default NULL,
  PRIMARY KEY  (type_name)
) TYPE=MyISAM;

#
# Dumping data for table 'ad_types'
#


#
# Table structure for table 'advertisers'
#

CREATE TABLE advertisers (
  advertisor_id int(11) NOT NULL default '0',
  contact_name varchar(255) NOT NULL default '',
  contact_phone varchar(20) default NULL,
  company_name varchar(255) NOT NULL default '',
  snail_mail varchar(255) default NULL,
  PRIMARY KEY  (advertisor_id)
) TYPE=MyISAM;


UPDATE blocks SET block = CONCAT(block, ',\r\nshowad') where bid = 'opcodes';
UPDATE blocks SET block = CONCAT(block, ',\r\nshowad=/ad_id/,\r\nadmin.1=ads:/tool/type/which') where bid = 'op_templates';

INSERT INTO blocks VALUES ('new_user_html','  <TR>\r\n   <TD COLSPAN=2 BGCOLOR=\"%%title_bgcolor%%\">%%title_font%%\r\n   <B>Create New User Account</B>%%title_font_end%%<P>\r\n   <FORM NAME=\"adduser\" METHOD=\"post\" ACTION=\"%%rootdir%%/\">\r\n   <INPUT TYPE=\"hidden\" name=\"tool\" VALUE=\"writeuser\">\r\n   <INPUT TYPE=\"hidden\" name=\"op\" VALUE=\"newuser\">\r\n   <INPUT TYPE=\"hidden\" name=\"formkey\" VALUE=\"%%formkey%%\">\r\n   </TD>\r\n  </TR>\r\n  <TR><TD COLSPAN=2><FONT COLOR=\"#FF0000\"><H3><CENTER>%%error%%</CENTER></H3></FONT></TD></TR>\r\n  <TR><TD COLSPAN=2>%%norm_font%%\r\n  This is where you start the two-step process of creating a new user account. Here is what you will do:\r\n  <UL><LI>Fill out this form. You will receive a confirmation email immediately, at the address you provide here.\r\n  <LI>Follow the instructions on that email to activate your account.\r\n  </UL>\r\n  It\'s that easy. Why do I require a working email account, and a confirmation? Mainly this is to prevent abuse of the story moderation system. It should at least make it harder for malicious users to create an arbitrary number of accounts and spam the site with stories. Your password will be mailed to this address, so it *must* work!\r\n  <P>\r\n  If you are concerned about privacy, this email does not have to be in any way traceable to you. I will never use the email you provide here for anything else, ever. All it needs to be is working, and accessable to you, at the time the account is created. \r\n  <P>\r\n  Now get started, and we hope you enjoy %%sitename%%!\r\n  %%norm_font_end%%</TD></TR>\r\n  <TR><TD COLSPAN=2>&nbsp;</TD></TR>\r\n  <TR>\r\n   <TD>\r\n   %%norm_font%%\r\n   Please enter your desired username:<BR>\r\n   %%norm_font_end%%\r\n   </TD>\r\n   <TD>\r\n   %%norm_font%%<INPUT TYPE=\"text\" NAME=\"nickname\" SIZE=30 VALUE=\"%%uname%%\">%%norm_font_end%%<BR>\r\n   </TD>\r\n  </TR>\r\n   <TD COLSPAN=2>\r\n   %%smallfont%%(Legal characters: a-z, A-Z, 0-9, space. Names may not start or end with a space, and may not contain more than one space in a row.)%%smallfont_end%%\r\n   </TD>\r\n  </TR>\r\n  <TR>\r\n   <TD>\r\n   %%norm_font%%\r\n   and a working email (this will never be made public!):<BR>\r\n   <B><FONT COLOR=\"#FF0000\">Check this for typos!</FONT></B>\r\n   %%norm_font_end%%\r\n   </TD>\r\n   <TD>\r\n   %%norm_font%%<INPUT TYPE=\"text\" NAME=\"email\" VALUE=\"%%email%%\" SIZE=30>%%norm_font_end%%\r\n   </TD>\r\n  </TR>',NULL,NULL);

INSERT INTO blocks VALUES ('basic_banner_ad_template','<!-- basic_banner_ad_template BEGIN -->\r\n<img src=\"%%ad_server_url%%%%IMAGE_PATH%%\"><BR>\r\n%%norm_font%% %%TEXT1%% %%norm_font_end%%<br>\r\n<!-- basic_banner_ad_template END -->',NULL,NULL);

INSERT INTO blocks VALUES ('new_advertiser_html','<tr><td colspan=\"2\"><input type=\"hidden\" name=\"advertiser\" value=\"1\">&nbsp;</td></tr>\r\n <TR>\r\n  <TD colspan=\"2\">%%norm_font%%\r\nSince you have expressed an interest in advertising on this site, I\'ll be needing a bit more\r\ninformation about you, for billing purposes. \r\n%%norm_font_end%%</TD>\r\n </TR>\r\n <TR>\r\n  <TD colspan=\"2\">%%norm_font%% %%advertising_account_disclaimer%% %%norm_font_end%% </TD>\r\n </TR>\r\n <TR>\r\n  <TD align=\"right\">%%norm_font%% Your Name: %%norm_font_end%%</TD>\r\n  <TD align=\"left\"> <input type=\"text\" name=\"realname\" value=\"%%yourname%%\" size=\"30\"></TD>\r\n </TR>\r\n <TR>\r\n  <TD align=\"right\">%%norm_font%% Business name: %%norm_font_end%%</TD>\r\n  <TD align=\"left\"><input type=\"text\" name=\"bizname\" value=\"%%bizname%%\" size=\"40\"> </TD>\r\n </TR>\r\n <TR>\r\n  <TD align=\"right\">%%norm_font%% Contact phone number: %%norm_font_end%%</TD>\r\n  <TD align=\"left\"><input type=\"text\" name=\"bizphone\" value=\"%%bizphone%%\" size=\"12\"> </TD>\r\n </TR>\r\n <TR>\r\n  <TD align=\"right\">%%norm_font%% Mailing Address: %%norm_font_end%%</TD>\r\n  <TD align=\"left\"><textarea cols=\"30\" rows=\"5\" name=\"snailmail\" value=\"%%snailmail%%\"></textarea></TD>\r\n </TR>\r\n',NULL,NULL);

INSERT INTO blocks VALUES ('advertising_account_disclaimer','Please remember the following with your new advertising account. <br><br><blockquote> <b>Any stories posted to this site for purely advertising purposes will void your contract with us.</b> The articles and diaries on this site are <b>not for advertising purposes</b>.  This account entitles you to submit ads for posting in specified places on the page only.  If you are caught abusing this account, you\'re ads will be disabled, no money will be refunded, and your account will be disabled.  If you have any questions about this send mail to %%local_email%%.\r\n</blockquote><br>  Thank you for your understanding.',NULL,NULL);

INSERT INTO blocks VALUES ('basic2_banner_ad_template','<!-- basic2_banner_ad_template BEGIN -->\r\n<a href=\"%%LINK_URL%%\"><img src=\"%%ad_server_url%%/%%IMAGE_PATH%%\"></A><BR>\r\n%%norm_font%%<b>%%TEXT1%%</b>%%norm_font_end%%<br>\r\n%%norm_font%% %%TEXT2%% %%norm_font_end%%<br>\r\n<!-- basic_banner_ad_template END -->',NULL,NULL);

INSERT INTO blocks VALUES ('ad_test_template','<HTML>\r\n<HEAD>\r\n<TITLE>%%slogan%%</TITLE>\r\n</HEAD>\r\n<BODY BGCOLOR=\"#FFFFFF\">%%BOX,show_ad,fromurl%%</body>\r\n</html>',NULL,NULL);

INSERT INTO box VALUES ('show_ad','Show Advertisement','my $arg1 = shift;\r\nmy $ad_id;\r\n\r\nif( $arg1 = \'fromurl\' ) {\r\n $ad_id = $S->{CGI}->param(\'ad_id\');\r\n}\r\n\r\nmy $adhash = $S->get_ad_hash($ad_id);\r\n\r\nmy $image = $adhash->{ad_file};\r\nmy $subdir = $adhash->{sponser};\r\n$subdir = \'example\' if( $adhash->{example} == 1 );\r\n\r\nmy $image_path = $subdir . \'/\' . $image;\r\n\r\nmy $content = $S->{UI}->{BLOCKS}->{ $adhash->{ad_templ} };\r\n\r\n$content =~ s/%%IMAGE_PATH%%/$image_path/g;\r\n$content =~ s/%%TEXT1%%/$adhash->{ad_text1}/g;\r\n$content =~ s/%%TEXT2%%/$adhash->{ad_text2}/g;\r\n$content =~ s/%%LINK_URL%%/$adhash->{ad_url}/g;\r\n\r\nreturn { content => $content };','Just a simple box that will show the ad specified','blank_box',0);

ALTER TABLE perm_groups DROP COLUMN allowed_sections;

UPDATE perm_groups SET group_perms = CONCAT(group_perms, ',ad_admin') where perm_group_id = 'Superuser' or perm_group_id = 'Admins';
INSERT INTO perm_groups VALUES ('Advertisers','attach_poll,comment_post,comment_rate,moderate,poll_post_comments,poll_read_comments,poll_vote,story_post,submit_rdf,view_polls',0,'Advertiser group, these people should be able to submit ads.');

INSERT INTO section_perms VALUES ('Advertisers','Diary',',norm_read_comments,norm_post_comments,norm_read_stories,norm_post_stories',0);
INSERT INTO section_perms VALUES ('Advertisers','news',',norm_read_comments,norm_post_comments,norm_read_stories,norm_post_stories',1);

INSERT INTO templates VALUES ('ad_test_template','showad');

INSERT INTO vars VALUES ('advertiser_group','Advertisers','This is the group that all new advertising accounts will get assigned to.  DO NOT CHANGE THIS AFTER SOME AD ACCOUNTS HAVE BEEN CREATED.  You will cause problems, unforseen ones, and probably the old accounts will cease\r\nto be even User level accounts.  Don\'t do it!  Unless you mail scoop-help and we explain how to safely :)','text','Advertising');
INSERT INTO vars VALUES ('use_ads','0','If 1, then your site will allow submission of ads.  Be sure to read the Enabling Ads section of the Scoop Administrators Guide before enabling these.  DO NOT ENABLE ADS!! This is in development.  Though it *shouldn\'t crash your machine, combust small pets, etc.  It could...  So DO NOT ENABLE on a site you are not using for pure development purposes.','bool','Advertising');
INSERT INTO vars VALUES ('ad_server_url','http://ads.bohr.hurstdog.org/','This is the url of your ad server.  I would reccomend putting the ads on a subdomain of your site, for easy logging and parsing by scripts.','text','Advertising');
INSERT INTO vars VALUES ('ad_files_base','/home/hurstdog/scoop/scoop/adfiles','This is the base directory for storing of all ads when uploaded. Make sure that this directory is readable and writeable by the user apache runs as.','text','Advertising');
INSERT INTO vars VALUES ('allow_html','0','If 1, allow people to post some html to go around their ad','bool','Advertising');
INSERT INTO vars VALUES ('allow_js','0','If 1, allow people to post some javascript to go with their ad','bool','Advertising');
INSERT INTO vars VALUES ('allow_java','0','If 1, allow people to post java ads','bool','Advertising');
INSERT INTO vars VALUES ('max_ad_upload_size','100','This is the maximum ad size that you will allow people to upload in KBytes.','num','Advertising');


