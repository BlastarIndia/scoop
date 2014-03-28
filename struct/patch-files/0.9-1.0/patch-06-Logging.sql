ALTER TABLE hooks ADD COLUMN enabled INT(1) DEFAULT 1;

#
# vars
#
INSERT INTO vars VALUES ('use_logging','0','Enable Administrator Logging functions? (1=yes, 2=extended)','num','General');

#
# admin tool
#
INSERT INTO admin_tools VALUES ('log',18,'Log','Log','view_log','view_log',0);

#
# blocks
#
UPDATE blocks SET block = CONCAT(block, ",\nview_log") WHERE bid = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms, ",view_log") WHERE perm_group_id = 'Superuser' OR perm_group_id = 'Admins' OR perm_group_id = 'Editors';
UPDATE blocks SET block = CONCAT(block, "\ncomment_delete(sid, cid)\nstory_delete(sid)") where bid = 'hooks';

#
# hooks
#
INSERT INTO hooks (hook, func, is_box, enabled) VALUES ('story_update', 'log_activity', 0, 0); 
INSERT INTO hooks (hook, func, is_box, enabled) VALUES ('story_new', 'log_activity', 0, 0); 
INSERT INTO hooks (hook, func, is_box, enabled) VALUES ('story_delete', 'log_activity', 0, 0); 
INSERT INTO hooks (hook, func, is_box, enabled) VALUES ('comment_delete', 'log_activity', 0, 0); 

#
# tables
#
CREATE TABLE log_info (
	log_id int(11) NOT NULL auto_increment,
	log_type varchar(30) NOT NULL default '',
	log_item varchar(30) NOT NULL default '',
	description varchar(255) default '',
	extended tinyint(1) NOT NULL default '0',
	uid int(11) NOT NULL default '0',
	ip_address varchar(30) default '',
	log_date datetime NOT NULL default '0000-00-00 00:00:00',
	PRIMARY KEY  (log_id)
);

CREATE TABLE log_info_extended (
	log_id int(11) NOT NULL default '0',
	extended_description text,
	PRIMARY KEY  (log_id)
);
