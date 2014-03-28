UPDATE blocks SET block = CONCAT(block, ",\nuse_spellcheck") WHERE bid = 'perms';
UPDATE perm_groups SET group_perms = CONCAT(group_perms, ',use_spellcheck') WHERE perm_group_id != 'Anonymous';
