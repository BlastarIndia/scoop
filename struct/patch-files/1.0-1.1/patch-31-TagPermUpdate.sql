UPDATE vars SET value = CONCAT(value,',\nedit_story_tags') where name = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms,',edit_story_tags') WHERE perm_group_id IN ('Superuser','Admins','Editors');
