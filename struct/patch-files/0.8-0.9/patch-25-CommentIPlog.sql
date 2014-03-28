INSERT INTO vars VALUES ('comment_ip_log',0,'If this var is set to 1, then the IP that a comment was posted from will be logged in the db. Hopefully it will be able to be used to identify possible problematic multiple account holders.','bool','Comments');
INSERT INTO vars VALUES ('view_ip_log',0,'If this var is set to 1 and comment_ip_log is on, then admins and superusers can see the IP a comment was posted from.','bool','Comments');
UPDATE perm_groups SET group_perms = CONCAT(group_perms, ',view_comment_ip') where perm_group_id = 'Superuser' or perm_group_id = 'Admins';
UPDATE blocks SET block = CONCAT(block, ",\nview_comment_ip") WHERE bid = 'perms';
ALTER TABLE comments add column commentip varchar(16);
