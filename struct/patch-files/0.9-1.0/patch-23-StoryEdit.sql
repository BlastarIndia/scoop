UPDATE vars SET value = CONCAT('', value, '\nstory_displaystatus_select,\nstory_commentstatus_select') WHERE name = 'perms';
