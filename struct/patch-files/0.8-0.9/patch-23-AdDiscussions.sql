ALTER TABLE ad_info add column ad_sid varchar(20);

INSERT INTO vars(name,value,description,type,category) VALUES ('ad_story_section','advertisements','This is the section that all ad stories will go into if you set use_ad_discussions to 1.  Not a good idea to change this after you\'ve already got some ads in this section.','text','Advertising');
INSERT INTO vars(name,value,description,type,category) VALUES ('ads_judge_unpaid','1','Turn this off if you only want to see ads on the judge submissions page after they\'ve been paid for.','bool','Advertising');
INSERT INTO vars(name,value,description,type,category) VALUES ('ad_story_topic','ads','This is the topic that all ad stories will use if you set use_ad_discussions to 1.  Not a good idea to change this after you\'ve already got some ads in this topic.','text','Advertising');
INSERT INTO vars(name,value,description,type,category) VALUES ('ads_in_everything_sec','0','Turn this on to have the ads listed in the everything section alongside stories.  0 to not have them listed there','bool','Advertising');

ALTER TABLE ad_types add column allow_discussion int(1) default '0';

INSERT INTO box VALUES ('ad_story_format','Ad Story formatter','my $ad_id = $ARGS[0];\r\n\r\nmy $content = qq{\r\n%%BOX,show_ad,$ad_id%%\r\n};\r\n\r\nreturn { content => $content };','Use this to format the advertisments in the introtext of their stories.','blank_box',0);

