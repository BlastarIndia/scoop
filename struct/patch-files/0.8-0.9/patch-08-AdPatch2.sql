
DELETE FROM ad_info;
DROP table ad_info;
CREATE TABLE ad_info (
  ad_id int(11) NOT NULL auto_increment,
  ad_tmpl varchar(30) default NULL,
  ad_file varchar(255) default NULL,
  ad_url varchar(255) default NULL,
  ad_text1 text,
  ad_text2 text,
  views_left int(11) default '0',
  first_day date default NULL,
  perpetual int(1) default '0',
  last_seen datetime default NULL,
  sponser int(6) NOT NULL default '0',
  active int(1) default '0',
  example int(1) default '0',
  ad_title varchar(255) default NULL,
  submitted_on datetime default NULL,
  view_count int(11) default '0',
  click_throughs int(11) default '0',
  PRIMARY KEY  (ad_id),
  KEY seen_active (active,last_seen,ad_tmpl)
);

INSERT INTO ad_info VALUES (1,'text_ad_template','','http://scoop.kuro5hin.org','The swiss army chainsaw of Content Management',NULL,NULL,NULL,NULL,NULL,1,NULL,1,'Scoop','2001-12-21 09:39:12',0,0);


DELETE FROM ad_types;
DROP TABLE ad_types;
CREATE TABLE ad_types (
  type_template varchar(30) NOT NULL default '',
  type_name varchar(50) NOT NULL default '',
  short_desc varchar(255) NOT NULL default '',
  submit_instructions text,
  max_file_size int(11) default NULL,
  max_text1_chars int(5) default NULL,
  max_text2_chars int(5) default NULL,
  max_title_chars int(5) default NULL,
  cpm decimal(7,2) default NULL,
  active int(1) NOT NULL default '0',
  min_purchase_size int(7) default NULL,
  PRIMARY KEY  (type_template)
);

INSERT INTO ad_types VALUES ('text_ad_template','Simple Text Ad','This is a simple text advertisement that allows a title, some text, and a link to your site.','Put in your title, text, and where you want to link to below.',0,50,NULL,20,2.50,1,1000);

UPDATE blocks set block = CONCAT(block, ',\nsubmitad') WHERE bid='opcodes';
UPDATE blocks set block = CONCAT(block, ',\nsubmitad=/step/,') WHERE bid='op_templates';

INSERT INTO blocks VALUES ('text_ad_template','<TABLE bgcolor=\"FFFFFF\" fgcolor=\"000000\" border=\"0\" cellpadding=\"2\" cellspacing=\"1\">\r\n<TR><TD><a href=\"%%LINK_URL%%\">%%norm_font%%%%TITLE%%%%norm_font_end%%</a></TD></TR>\r\n<TR><TD>%%norm_font%%%%TEXT1%%%%norm_font_end%%</TD></TR>\r\n</TABLE>',NULL,NULL);

INSERT INTO blocks VALUES ('ad_step1_rules','<!-- ad_step1_rules.  Do not take out the |NEXT_LINK| text, as it will be replaced with a button to get the user to the next step in the process -->\r\n<TABLE BORDER=0 WIDTH=\"99%\" ALIGN=\"center\" CELLPADDING=0 CELLSPACING=10>\r\n<TR>\r\n        <TD VALIGN=\"top\" width=\"55%\" BGCOLOR=\"%%title_bgcolor%%\">\r\n            %%title_font%% Rules for Submitting Ads %%title_font_end%%\r\n        </TD>\r\n</TR>\r\n<TR>\r\n<TD>%%norm_font%%\r\n<ul>\r\n<li>These are the rules for submitting ads on this Scoop site.\r\n</ul>\r\n%%norm_font_end%%\r\n</TD>\r\n</TR>\r\n<TR><TD>%%norm_font%% %%NEXT_LINK%% %%norm_font_end%%\r\n</TABLE>',NULL,NULL);

INSERT INTO blocks VALUES ('error_template','<h1>%%ERROR_TYPE%%</h1>\r\n<p>\r\n<b>Time:</b> %%thetime%%<br>\r\n<b>Package:</b> %%package%%<br>\r\n<b>File:</b> %%file%% <br>\r\n<b>Line:</b> %%line%% <br>\r\n<b>Additional Messages:</b> %%ERROR_MSG%%\r\n<b>Var Dump:</b><br>\r\n%%VARDUMP%%\r\n</p>',NULL,NULL);

INSERT INTO blocks VALUES ('ad_confirm_text','<p>Your ad is shown above for you to make sure that its how you want it.  If you see any problems,\r\nhit back and fix them.  Make sure that you take note of how much this will cost, as the next step\r\nis where you pay. If you like what you see, hit \"Purchase Ad\" below, if not, hit back and make your\r\nchanges.</p>',NULL,NULL);

INSERT INTO blocks VALUES ('no_submit_ad_perm','<TABLE BORDER=0 CELLPADDING=1 CELLSPACING=1 WIDTH=\"99%\"> \r\n<TR><TD bgcolor=\"%%title_bgcolor%%\">%%title_font%% Submit Ad Error %%title_font_end%%</TD></TR>\r\n<TR><TD >%%norm_font%% Sorry, but you must have a user account or login before you can submit ads on this site.  You may login using the box to your right.  To create an account you may go <a href=\"%%rootdir%%/newuser\">here</a>%%norm_font_end%%</TD></TR>\r\n</TABLE>\r\n',NULL,NULL);

UPDATE box set content = 'my $arg0 = $ARGS[0];\r\nmy $ad_id;\r\nmy $adhash = {};\r\n\r\n# if the ad_id is in the url, use the url\r\nif( $arg0 eq \'fromurl\' || $arg0 eq \'allcgi\' ) {\r\n $ad_id = $S->{CGI}->param(\'ad_id\');\r\n\r\n# else if ad_id is specified in template, use that\r\n} elsif( $arg0 =~ /\\d/ ) {\r\n $ad_id = $arg0;\r\n}\r\n\r\n\r\nunless( defined( $ad_id ) || $arg0 eq \'allcgi\' ) {\r\n  warn \"returning due to no ad_id in show_ad box\";\r\n  return \'\';\r\n}\r\n\r\n# if we need everything from cgi, let get_ad_hash know\r\nmy $source = \'db\';\r\n$source = \'cgi\' if( $arg0 eq \'allcgi\' );\r\n\r\n$adhash = $S->get_ad_hash($ad_id, $source);\r\n\r\nmy $image = $adhash->{ad_file};\r\nmy $subdir = $adhash->{sponser};\r\n$subdir = \'example\' if( $adhash->{example} == 1 );\r\n\r\nmy $image_path = $subdir . \'/\' . $image;\r\n\r\nmy $content = $S->{UI}->{BLOCKS}->{ $adhash->{ad_tmpl} };\r\n\r\n$content =~ s/%%FILE_PATH%%/$image_path/g;\r\n$content =~ s/%%TEXT1%%/$adhash->{ad_text1}/g;\r\n$content =~ s/%%TEXT2%%/$adhash->{ad_text2}/g;\r\n$content =~ s/%%TITLE%%/$adhash->{ad_title}/g;\r\n$content =~ s/%%LINK_URL%%/$adhash->{ad_url}/g;\r\n\r\nreturn { content => $content };' where boxid = 'show_ad';

INSERT INTO box VALUES ('submit_ad_pay_box','Ad Submitted','my $content = qq{\r\n<p> Now that you\'ve submitted the ad, it has to be approved.  Our crack team of site maintainers who pore over all of the ad submissions daily will notice yours has arrived, and approve it so that it can be displayed on the site.  If for some reason they don\'t see fit to approve it, you will get an email sent to your real_email address explaining why.</p>\r\n<p> But wait! There\'s more!  Your ad will not be approved until it has been paid for.  Depending on how we do payment, that could be sooner or later.</p>\r\n<p> Thanks for advertising with %%sitename%% </p>\r\n};\r\n\r\nreturn { content => $content };','This generates the page the user will see when they have successfully submitted an ad.  This should direct them on how to pay for the ad, and\r\nexplain the details of what will happen now. ','box',0);

INSERT INTO box VALUES ('ad_box','Advertisement','return \'\' unless( $S->{UI}->{VARS}->{use_ads} );\r\n\r\nmy $adhash = $S->get_next_ad();\r\nreturn \'\' unless( defined $adhash );\r\n\r\nmy $content = $S->{UI}->{BLOCKS}->{$adhash->{ad_tmpl}};\r\n\r\n$content =~ s/%%LINK_URL%%/$adhash->{ad_url}/g;\r\n$content =~ s/%%TITLE%%/$adhash->{ad_title}/g;\r\n$content =~ s/%%TEXT1%%/$adhash->{ad_text1}/g;\r\n$content =~ s/%%TEXT2%%/$adhash->{ad_text2}/g;\r\n$content =~ s/%%FILE_PATH%%/$adhash->{ad_file}/g;\r\n\r\nreturn { content => $content };','Simple ad box for the side of the page','box',0);

UPDATE perm_groups set group_perms = CONCAT(group_perms, ',submit_ad') where perm_group_id != 'Anonymous';
UPDATE perm_groups set group_perms = CONCAT(group_perms, ',ad_admin') where perm_group_id = 'Superuser' OR perm_group_id = 'Admins';

INSERT INTO templates VALUES ('submit_template','submitad');
DELETE from vars where name = 'allow_html' or name = 'allow_js' or name = 'allow_java' or name = 'max_ad_upload_size';
INSERT INTO vars VALUES ('req_extra_advertiser_info','0','If this is on, then to submit an ad you have to fill out the advertiser information form.  NOTE: Leave this off for now, its being put to the back burner until we get a working implementation of text ads, which don\'t require this.','bool','Advertising');

