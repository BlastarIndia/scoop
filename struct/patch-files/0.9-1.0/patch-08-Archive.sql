
--
-- Change pollquestions table
--


ALTER TABLE pollquestions ADD COLUMN archived int(1) DEFAULT 0;

--
-- Dumping data for table 'vars'
--

INSERT INTO vars VALUES ('poll_archive_age','0','Polls that are over this many days old (ie, at least this old, and with no votes for that period) are archived','num','Polls');
INSERT INTO vars VALUES ('archive_ratings','1','Shall we archive comment ratings?','bool','Comments');
INSERT INTO vars VALUES ('archive_moderations','1','Shall we archive story moderations?','bool','Stories');
INSERT INTO vars VALUES ('comment_archive_age','31','Stories will only be archived if there are no comments newer than this figure attatched to them. If set to 0, then comment age is ignored when archiving.','num','Comments');
INSERT INTO vars VALUES ('story_archive_age','0','Stories over this many days old will be archived if no comments newer than comment_archive_age have been posted to them','num','Stories');


--
-- Dumping data for table 'cron'
--

INSERT INTO cron VALUES ('poll_archive','poll_archive',60,'2002-09-27 13:20:59',0,0);
INSERT INTO cron VALUES ('archive_stories','archive_stories',86400,'2002-10-18 21:00:01',0,0);

--
-- Update admin_tools
--

UPDATE admin_tools SET pos = pos+1 where pos >= 3;

INSERT INTO admin_tools VALUES ('archivelist',3,'Stories','Archived Story List','story_list','list_archive',0);
