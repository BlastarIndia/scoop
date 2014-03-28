ALTER TABLE stories ADD edit_category bool NOT NULL;
#
# Table structure for table 'editcategorycodes'
#

CREATE TABLE editcategorycodes (
  code int(1) NOT NULL default '0',
  name varchar(32) default NULL,
  orderby int(1) NOT NULL default '0',
  PRIMARY KEY  (code)
);

#
# Dumping data for table 'editcategorycodes'
#

INSERT INTO editcategorycodes VALUES (1,'Submitted',0);
INSERT INTO editcategorycodes VALUES (2,'Pending',0);

#
# new vars
#

INSERT INTO vars VALUES ('use_edit_categories','0','Should the moderation queue display editing categories?','bool','Stories');
INSERT INTO vars VALUES ('story_auto_vote_zero','0','This will automatically vote 0 when any user views the story in the moderation queue.','bool','Stories');
INSERT INTO vars VALUES ('editorial_comment_default', '0','Should an editor be able to toggle the comments between editorial and normal?','bool','Comments');

#
# blocks
#
UPDATE blocks SET block = CONCAT(block, ",\neditorial_comments") WHERE bid = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms, ",editorial_comments") WHERE perm_group_id = 'Superuser' OR perm_group_id = 'Admins' OR perm_group_id = 'Editors' OR perm_group_id = 'Users' OR perm_group_id = 'Advertisers';
