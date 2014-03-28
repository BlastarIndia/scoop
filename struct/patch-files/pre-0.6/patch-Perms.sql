#
# Table structure for table 'perm_groups'
#
CREATE TABLE perm_groups (
  perm_group_id varchar(50) DEFAULT '' NOT NULL,
  group_perms text,
  default_user_group int(1) DEFAULT '0',
  group_description text,
  PRIMARY KEY (perm_group_id)
);

#
# Dumping data for table 'perm_groups'
#

INSERT INTO perm_groups VALUES ('Anonymous','',0,'Anonymous users');
INSERT INTO perm_groups VALUES ('Users','attach_poll,comment_post,comment_rate,moderate,poll_vote,story_post',1,'Normal users. This should be the default perm level probably.');
INSERT INTO perm_groups VALUES ('Editors','attach_poll,comment_post,comment_rate,edit_polls,edit_special,list_polls,moderate,poll_vote,story_admin,story_list,story_post',0,'Editorial administrators');
INSERT INTO perm_groups VALUES ('Admins','attach_poll,comment_delete,comment_post,comment_rate,edit_blocks,edit_polls,edit_sections,edit_special,edit_user,edit_vars,list_polls,moderate,poll_vote,show_perms,story_admin,story_list,story_post\"',0,'Site administrators');
INSERT INTO perm_groups VALUES ('Superuser','attach_poll,comment_delete,comment_post,comment_rate,edit_blocks,edit_boxes,edit_groups,edit_perms,edit_polls,edit_sections,edit_special,edit_templates,edit_topics,edit_user,edit_vars,list_polls,moderate,poll_vote,show_perms,story_admin,story_list,story_post',0,'All permissions');

alter table users add perm_group varchar(50);

update users set perm_group = "Anonymous" where seclev = "0";
update users set perm_group = "Users" where seclev = "1";
update users set perm_group = "Admins" where seclev > 1 AND seclev < 10000;
update users set perm_group = "Superuser" where seclev = 10000;
