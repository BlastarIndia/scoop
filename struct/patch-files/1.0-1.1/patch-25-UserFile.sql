UPDATE vars SET value = CONCAT(value,',\nview_user_files') WHERE name = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms,',view_user_files') WHERE perm_group_id IN ('Superuser','Admins','Editors','Advertisers','Users');
